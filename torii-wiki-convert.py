#!/usr/bin/env python3

# torii: pasa la wiki de lazer-web a markdown de osu-wiki.
#
# Hoy la wiki de Torii son ocho paginas de React embebidas en el SPA. osu-web no
# lee la base para la wiki: lee un repositorio de github con la estructura
# wiki/<Pagina>/<idioma>.md y lo renderiza a elasticsearch. Asi que el contenido
# hay que mudarlo, no reescribirlo.
#
# Y mudarlo y no reescribirlo es literal: este script traduce los componentes a
# markdown y deja el texto EXACTAMENTE como esta. Reescribir a mano seis mil
# palabras que ya escribio una persona solo consigue que suenen distinto.
#
# Cada pagina se armo con la estructura que le convenia (unas con componentes,
# otras con un array de datos), asi que hay un lector por forma y todos corren
# sobre todas: varias mezclan las dos cosas.
#
#   Section  -> ## titulo
#   Panel    -> ### titulo
#   RuleList -> lista numerada
#   Callout  -> ::: alert-tip / alert-note / alert-warning / alert-caution
#   BotQuote -> cita en bloque
#   Prose    -> parrafos
#   <p>      -> parrafo (tres paginas escriben la prosa en jsx crudo, no en Prose)
#   SECTIONS -> ## heading + el body, que ya viene escrito en markdown
#   FAQ      -> ## pregunta + respuesta
#   GROUPS   -> ## categoria + una linea por feature
#   *_COMMANDS -> tabla de comandos
#   HubCard  -> un titulo con link por pagina
#   Toc      -> se descarta, osu-web arma su propio indice
#
# Uso:
#   python torii-wiki-convert.py <dir de lazer-web/src/pages/wiki> <dir salida>

import html
import pathlib
import re
import sys
import urllib.parse

# Nombre del archivo tsx (sin Wiki ni Page) -> pagina en la url de osu-web.
PAGES = {
    # osu-web redirige /wiki a /wiki/<idioma>/Main_page, asi que el indice
    # tiene que llamarse asi o la wiki entra por un 404.
    'Hub': 'Main_page',
    'Rules': 'Rules',
    'Faq': 'FAQ',
    'Features': 'Features',
    'Economy': 'Torii_points',
    'Scoring': 'Scoring',
    'Restrictions': 'Restrictions',
    'ToriiHalo': 'ToriiHalo',
}

# ruta en lazer-web -> pagina en osu-web
WIKI_PATHS = {
    'rules': 'Rules',
    'features': 'Features',
    'scoring': 'Scoring',
    'economy': 'Torii_points',
    'toriihalo': 'ToriiHalo',
    'restrictions': 'Restrictions',
    'faq': 'FAQ',
}

# tone del Callout -> bloque de osu-wiki.
#
# Los nombres NO son libres. El parser toma lo que sigue a los dos puntos, lo
# pasa a minusculas, y si no esta en style_block_allowed_classes (OsuMarkdown,
# linea 99) tira el envoltorio y deja el texto suelto. O sea que un ::: Tip
# renderiza igual que si no hubiera bloque, sin avisar.
TONES = {
    'good': 'alert-tip',
    'info': 'alert-note',
    'warn': 'alert-warning',
    'danger': 'alert-caution',
}

COMMAND_TITLES = {
    'OSU_COMMANDS': 'osu! commands',
    'ECONOMY_COMMANDS': 'Economy commands',
    'LINK_COMMANDS': 'Account linking',
    'FUN_COMMANDS': 'Fun commands',
}

STR = r'"((?:[^"\\]|\\.)*)"'


def unquote(text: str) -> str:
    return text.replace('\\"', '"').replace("\\'", "'").replace('\\n', '\n')


# <Link to="..."> o <a href="...">, con el destino entre comillas o como
# constante (href={DISCORD_INVITE}). Sin la rama de la constante el <a> se caia
# en el paso que borra tags y el link al Discord se perdia en Rules y en
# Restrictions, justo en las dos frases que piden ir al Discord.
LINK = re.compile(
    r'<(?:Link|a)\s[^>]*?(?:to|href)=(?:"([^"]+)"|\{([A-Z_][A-Z_0-9]*)\})[^>]*>(.*?)</(?:Link|a)>',
    re.S)


def resolve_const(target: str, source: str) -> str:
    """Cambia el nombre de una constante por su valor, buscandolo en el archivo."""
    if source and re.fullmatch(r'[A-Z_][A-Z_0-9]*', target):
        const = re.search(r'const ' + target + r'\s*=\s*"([^"]+)"', source)
        if const is not None:
            return const.group(1)

    return target


def strip_jsx(text: str, source: str = '') -> str:
    """Deja solo el texto, conservando enlaces y enfasis."""
    text = LINK.sub(
        lambda m: '[{}]({})'.format(m.group(3), resolve_const(m.group(1) or m.group(2), source)),
        text)
    text = re.sub(r'<(?:strong|b)>(.*?)</(?:strong|b)>', r'**\1**', text, flags=re.S)
    text = re.sub(r'<(?:em|i)>(.*?)</(?:em|i)>', r'*\1*', text, flags=re.S)
    text = re.sub(r'<code[^>]*>(.*?)</code>', r'`\1`', text, flags=re.S)
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'</?[A-Za-z][^>]*>', '', text)
    text = re.sub(r'</?>', '', text)
    # expresiones sueltas de jsx
    text = re.sub(r'\{"\s*"\}', ' ', text)
    text = re.sub(r"\{'([^']*)'\}", r'\1', text)
    text = re.sub(r'\{"([^"]*)"\}', r'\1', text)
    # Los links internos apuntan a las rutas del spa (/wiki/economy) y osu-web
    # usa otras (/wiki/Torii_points).
    text = re.sub(r'\]\((/wiki/[^)]+)\)', lambda m: '](' + wiki_link(m.group(1)) + ')', text)

    return html.unescape(text).strip()


def collapse(text: str) -> str:
    """Un parrafo por linea: el jsx viene cortado por ancho de columna."""
    paras = [re.sub(r'\s+', ' ', p).strip() for p in re.split(r'\n\s*\n', text)]

    return '\n\n'.join(p for p in paras if p)


# Rutas del spa que en osu-web se llaman de otra forma o directamente no
# existen. Sin esto quedan links a paginas que dan 404.
SPA_ROUTES = {
    '/how-to-join': '/home/download',
}

# pagina#id-del-Section -> ancla de osu-web. Se llena de una pasada antes de
# convertir porque el link vive en una pagina y la seccion a la que apunta esta
# en otra.
ANCHORS = {}


def heading_slug(title: str) -> str:
    """El ancla que osu-web le pone a un encabezado.

    Es lo que hace DocumentProcessor::loadToc: minusculas, los espacios a guion
    y percent-encoding del resto. O sea que la seccion "6. Enforcement" queda
    como "6.-enforcement" y el #enforcement pelado del spa no engancha con nada;
    el link te deja al principio de la pagina sin decir nada."""
    return urllib.parse.quote(title.lower().replace(' ', '-'), safe="!'()")


def collect_anchors(source: str, page: str) -> None:
    for m in re.finditer(r'<Section\s([^>]*)>', source):
        sid = re.search(r'id="([^"]+)"', m.group(1))
        title = re.search(r'title="([^"]+)"', m.group(1))
        if sid is not None and title is not None:
            ANCHORS[page + '#' + sid.group(1)] = heading_slug(title.group(1))


def wiki_link(target: str, source: str = '') -> str:
    # Los HubCard pueden apuntar a una constante en vez de a una cadena
    # (to={DISCORD_INVITE}). Se resuelve contra el archivo o el link sale con el
    # nombre de la variable adentro de la url.
    target = resolve_const(target, source)

    if target.startswith('/wiki/'):
        # El ancla se separa antes de traducir la ruta: /wiki/rules#enforcement
        # no esta en la tabla y sin cortarlo caia en el capitalize de abajo, que
        # acierta de casualidad.
        slug, sep, anchor = target[len('/wiki/'):].partition('#')
        page = WIKI_PATHS.get(slug, slug.capitalize())

        return '/wiki/' + page + sep + ANCHORS.get(page + '#' + anchor, anchor)

    return SPA_ROUTES.get(target, target)


def template_sections(source: str) -> list:
    """const SECTIONS = [{heading, body}]. El body ya es markdown, va tal cual."""
    out = []
    for m in re.finditer(r'heading:\s*"([^"]+)",\s*body:\s*`(.*?)`', source, re.S):
        out.append('## ' + m.group(1))
        out.append(m.group(2).strip())

    return out


def faq_items(source: str) -> list:
    """const FAQ = [{q, a}]."""
    out = []
    for m in re.finditer(r'q:\s*' + STR + r',\s*a:\s*\(\s*<>(.*?)</>\s*\)', source, re.S):
        out.append('## ' + unquote(m.group(1)))
        out.append(collapse(strip_jsx(m.group(2), source)))

    return out


def feature_groups(source: str) -> list:
    """const GROUPS = [{category, features: [{name, description}]}]."""
    out = []
    blocks = re.split(r'\n\s*category:\s*', source)
    for block in blocks[1:]:
        name = re.match(r'"([^"]+)"', block)
        if name is None:
            continue

        out.append('## ' + name.group(1))
        rows = []
        for f in re.finditer(r'name:\s*' + STR + r',\s*description:\s*' + STR, block, re.S):
            rows.append('- **{}** {}'.format(unquote(f.group(1)), collapse(unquote(f.group(2)))))

        out.append('\n'.join(rows))

    return out


def cell(text: str) -> str:
    """Escapa la barra para una celda de tabla.

    La barra corta la celda incluso adentro de un `codigo`, asi que el args de
    /coinflip (<amount> <heads|tails>) partia la fila en cuatro columnas y la
    tabla, que tiene tres, se comia la descripcion entera."""
    return text.replace('|', r'\|')


def command_table(source: str, name: str) -> str:
    """const <name> = [{name, args, desc}] -> una tabla de markdown.

    Las tablas de comandos se declaran arriba como datos y se dibujan abajo con
    <CommandTable commands={X} />, o sea que hay que emitirlas EN el lugar donde
    se dibujan y no todas juntas al final: si no, las secciones de la pagina
    quedan vacias y las tablas amontonadas abajo."""
    block = re.search(r'const ' + re.escape(name) + r'[^=]*=\s*\[(.*?)\n\];', source, re.S)
    if block is None:
        return ''

    rows = ['| Command | Arguments | What it does |', '| :-- | :-- | :-- |']
    for c in re.finditer(r'name:\s*"([^"]+)"(?:,\s*args:\s*"([^"]*)")?,\s*desc:\s*' + STR,
                         block.group(1), re.S):
        args = '`{}`'.format(cell(c.group(2))) if c.group(2) else ''
        rows.append('| `{}` | {} | {} |'.format(
            cell(c.group(1)), args, cell(collapse(unquote(c.group(3))))))

    return '\n'.join(rows) if len(rows) > 2 else ''


def hub_cards(source: str) -> list:
    """El indice: los tiles pasan a ser un titulo con link por pagina.

    Nada de html crudo. El preset de la wiki no lo deja pasar (html_input no
    esta en allow), asi que probe con los div de paneles de osu-wiki y
    desaparecen sin dejar rastro: solo ensucian el markdown.

    Titulos y no vinetas porque osu-web arma el indice lateral con los
    encabezados, asi que de paso el indice de la wiki tiene su propio indice."""
    cards = re.findall(r'<HubCard\s+to=\{?"?([^"}\s]+)"?\}?[^>]*title="([^"]+)"', source)

    return ['\n\n'.join('## [{}]({})'.format(title, wiki_link(target, source))
                        for target, title in cards)] if cards else []


def closing_bracket(source: str, start: int) -> int:
    """Indice del ] que cierra el [ que esta en start.

    Contar corchetes y no buscar el fin del tag: los items pueden traer
    corchetes en el texto y comillas con cualquier cosa adentro."""
    depth = 0
    i = start
    while i < len(source):
        c = source[i]
        if c == '[':
            depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0:
                return i
        elif c == '"':
            i = end_of_string(source, i)

        i += 1

    return -1


def end_of_string(source: str, start: int) -> int:
    """Indice de la comilla que cierra la que esta en start."""
    i = start + 1
    while i < len(source) and source[i] != '"':
        i += 2 if source[i] == '\\' else 1

    return i


def rule_items(block: str) -> list:
    """Los items de un RuleList: cadenas sueltas o fragmentos <>...</>.

    Se recorre a mano en vez de barrer con una regex de cadenas porque los
    fragmentos traen atributos entrecomillados (target="_blank", className=...)
    y salian como items por su cuenta, tapando al item de verdad: la lista de
    "How to appeal" de Restrictions eran tres clases de css."""
    items = []
    i = 0
    while i < len(block):
        if block[i] == '"':
            end = end_of_string(block, i)
            items.append(unquote(block[i + 1:end]))
            i = end + 1
        elif block.startswith('<>', i):
            end = block.find('</>', i)
            if end < 0:
                break

            items.append(block[i + 2:end])
            i = end + len('</>')
        else:
            i += 1

    return items


def blockquote(text: str) -> str:
    """Cita en bloque, cada linea con su >, para que los parrafos no se peguen."""
    return '\n'.join('> ' + line if line else '>' for line in text.split('\n'))


def components(source: str) -> list:
    """Section, Callout, BotQuote, Prose, Panel, <p> y RuleList, en orden."""
    out = []
    pattern = re.compile(
        r'<Section\s+[^>]*title="([^"]+)"[^>]*>'
        r'|<Panel\s+[^>]*title="([^"]+)"[^>]*>'
        r'|<Callout\b([^>]*)>'
        r'|<BotQuote\b([^>]*)>'
        r'|<Prose\s+body=\{?[`"](.*?)[`"]\}?\s*/>'
        r'|<CommandTable\s+commands=\{([A-Z_]+)\}\s*/>'
        r'|<p(?=[\s>])[^>]*>'
        r'|<RuleList\b',
        re.S)

    pos = 0
    while True:
        m = pattern.search(source, pos)
        if m is None:
            break

        pos = m.end()
        opener = m.group(0)

        if m.group(1):
            out.append('## ' + m.group(1))
        elif m.group(2):
            out.append('### ' + m.group(2))
        elif opener.startswith('<Callout'):
            tone = re.search(r'tone="([^"]+)"', m.group(3))
            title = re.search(r'title="([^"]+)"', m.group(3))
            end = source.find('</Callout>', pos)
            inner = collapse(strip_jsx(source[pos:end], source))
            # El titulo va en su propia linea, como los avisos de osu-web: el
            # preset de la wiki convierte el salto simple en un <br>.
            head = '**{}**{}'.format(title.group(1), chr(10)) if title else ''
            out.append('::: {}\n{}{}\n:::'.format(
                TONES.get(tone.group(1) if tone else 'info', 'alert-note'), head, inner))
            pos = end
        elif opener.startswith('<BotQuote'):
            # El from default lo pone el componente, asi que si no esta hay que
            # repetirlo aca o la cita queda sin decir quien habla.
            who = re.search(r'from="([^"]+)"', m.group(4))
            end = source.find('</BotQuote>', pos)
            inner = collapse(strip_jsx(source[pos:end], source))
            out.append(blockquote('**{} says**\n{}'.format(
                who.group(1) if who else 'ToriiHalo', inner)))
            pos = end
        elif m.group(5):
            out.append(collapse(strip_jsx(m.group(5), source)))
        elif m.group(6):
            out.append(command_table(source, m.group(6)))
        elif opener.startswith('<p'):
            end = source.find('</p>', pos)
            if end < 0:
                continue

            text = collapse(strip_jsx(source[pos:end], source))
            # Los <p> del jsx son dos cosas distintas: prosa escrita a mano y
            # plantilla adentro de un .map() (<p>{item.a}</p>, FAQ y Features).
            # Si quedo una llave despues de limpiar el jsx es lo segundo, y
            # emitirlo escupe "{item.a}" en la wiki. El texto de verdad va por
            # otro lector.
            if text and '{' not in text:
                out.append(text)

            pos = end
        else:
            start = source.find('[', pos)
            end = closing_bracket(source, start)
            if start < 0 or end < 0:
                continue

            items = [collapse(strip_jsx(item, source))
                     for item in rule_items(source[start + 1:end])]
            out.append('\n'.join(
                '{}. {}'.format(i, t) for i, t in enumerate([t for t in items if t], 1)))
            pos = end

    return out


def convert(source: str) -> tuple:
    title = re.search(r'title="([^"]+)"', source)
    # El intro se escribe en una linea o en varias segun el largo, asi que el
    # \s* no es cosmetico: sin el, cinco de las ocho paginas arrancaban sin la
    # frase que dice de que va la pagina.
    intro = re.search(r'intro=\{\s*<>(.*?)</>\s*\}', source, re.S)

    body = []
    if intro:
        body.append(collapse(strip_jsx(intro.group(1), source)))

    for reader in (components, template_sections, faq_items,
                   feature_groups, hub_cards):
        body.extend(reader(source))

    return (title.group(1) if title else 'Torii'), '\n\n'.join(b for b in body if b.strip())


def main() -> int:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])

    sources = {}
    for key, page in PAGES.items():
        path = src / 'Wiki{}Page.tsx'.format(key)
        if not path.exists():
            print('falta {}, se saltea'.format(path.name))
            continue

        sources[key] = path.read_text(encoding='utf-8')
        collect_anchors(sources[key], page)

    for key, source in sources.items():
        page = PAGES[key]
        path = src / 'Wiki{}Page.tsx'.format(key)
        title, body = convert(source)
        target = out / 'wiki' / page / 'en.md'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('# {}\n\n{}\n'.format(title, body), encoding='utf-8', newline='\n')
        print('{:28} -> wiki/{}/en.md  ({} palabras)'.format(path.name, page, len(body.split())))

    return 0


if __name__ == '__main__':
    sys.exit(main())
