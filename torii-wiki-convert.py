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
#   Prose    -> parrafos
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


def strip_jsx(text: str) -> str:
    """Deja solo el texto, conservando enlaces y enfasis."""
    text = re.sub(r'<(?:Link|a)\s[^>]*?(?:to|href)=\{?"([^"]+)"\}?[^>]*>(.*?)</(?:Link|a)>',
                  r'[\2](\1)', text, flags=re.S)
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


def wiki_link(target: str, source: str = '') -> str:
    # Los HubCard pueden apuntar a una constante en vez de a una cadena
    # (to={DISCORD_INVITE}). Se resuelve contra el archivo o el link sale con el
    # nombre de la variable adentro de la url.
    if source and re.fullmatch(r'[A-Z_]+', target):
        const = re.search(r'const ' + target + r'\s*=\s*"([^"]+)"', source)
        if const is not None:
            return const.group(1)

    if target.startswith('/wiki/'):
        slug = target[len('/wiki/'):]

        return '/wiki/' + WIKI_PATHS.get(slug, slug.capitalize())

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
        out.append(collapse(strip_jsx(m.group(2))))

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
        args = '`{}`'.format(c.group(2)) if c.group(2) else ''
        rows.append('| `{}` | {} | {} |'.format(
            c.group(1), args, collapse(unquote(c.group(3)))))

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


def components(source: str) -> list:
    """Section, Callout, Prose, Panel y RuleList, en orden de aparicion."""
    out = []
    pattern = re.compile(
        r'<Section\s+[^>]*title="([^"]+)"[^>]*>'
        r'|<Panel\s+[^>]*title="([^"]+)"[^>]*>'
        r'|<Callout\b([^>]*)>'
        r'|<Prose\s+body=\{?[`"](.*?)[`"]\}?\s*/>'
        r'|<CommandTable\s+commands=\{([A-Z_]+)\}\s*/>'
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
            inner = collapse(strip_jsx(source[pos:end]))
            # El titulo va en su propia linea, como los avisos de osu-web: el
            # preset de la wiki convierte el salto simple en un <br>.
            head = '**{}**{}'.format(title.group(1), chr(10)) if title else ''
            out.append('::: {}\n{}{}\n:::'.format(
                TONES.get(tone.group(1) if tone else 'info', 'alert-note'), head, inner))
            pos = end
        elif m.group(4):
            out.append(collapse(strip_jsx(m.group(4))))
        elif m.group(5):
            out.append(command_table(source, m.group(5)))
        else:
            end = source.find('/>', pos)
            if end < 0:
                continue

            items = []
            for item in re.finditer(STR + r'|<>(.*?)</>', source[pos:end], re.S):
                raw = item.group(1) if item.group(1) is not None else item.group(2)
                text = collapse(strip_jsx(unquote(raw)))
                if text:
                    items.append(text)

            out.append('\n'.join(
                '{}. {}'.format(i, t) for i, t in enumerate(items, 1)))
            pos = end

    return out


def convert(source: str) -> tuple:
    title = re.search(r'title="([^"]+)"', source)
    intro = re.search(r'intro=\{<>(.*?)</>\}', source, re.S)

    body = []
    if intro:
        body.append(collapse(strip_jsx(intro.group(1))))

    for reader in (components, template_sections, faq_items,
                   feature_groups, hub_cards):
        body.extend(reader(source))

    return (title.group(1) if title else 'Torii'), '\n\n'.join(b for b in body if b.strip())


def main() -> int:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])

    for key, page in PAGES.items():
        path = src / 'Wiki{}Page.tsx'.format(key)
        if not path.exists():
            print('falta {}, se saltea'.format(path.name))
            continue

        title, body = convert(path.read_text(encoding='utf-8'))
        target = out / 'wiki' / page / 'en.md'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('# {}\n\n{}\n'.format(title, body), encoding='utf-8', newline='\n')
        print('{:28} -> wiki/{}/en.md  ({} palabras)'.format(path.name, page, len(body.split())))

    return 0


if __name__ == '__main__':
    sys.exit(main())
