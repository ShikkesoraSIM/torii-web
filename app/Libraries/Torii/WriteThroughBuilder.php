<?php

// torii: los update y delete de query builder tambien tienen que pasar por
// WriteThrough.
//
// WriteThrough se engancha en el modelo (performInsert, performUpdate,
// performDeleteOnModel), asi que solo ve las escrituras de instancia. Un
// ->where(...)->delete() no carga instancias: compila un solo DELETE y se va
// derecho contra la vista. Eso es un 500 en el mejor caso (score_pins, que tiene
// join a proposito) y una escritura perdida en el peor.
//
// Se podria arreglar call-site por call-site cargando la instancia antes de
// escribir, y hoy son cuatro. No se hizo asi porque esa lista no es estable:
// osu-web upstream agrega y mueve esas llamadas, y el proximo sync las trae de
// vuelta sin que nadie se acuerde de este archivo. El gancho es uno solo y
// cubre las que vengan.
//
// El precio es que la operacion pasa de una consulta a N mas una. Solo se paga
// en las tablas que el mapa declara, y ahi se tocan de a una fila (un pin, un
// miembro de equipo): las masivas de verdad (favoritos, amigos) no estan en el
// mapa justamente porque MySQL las propaga sola.

declare(strict_types=1);

namespace App\Libraries\Torii;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;

class WriteThroughBuilder extends Builder
{
    /**
     * Lo prende Model::performUpdate antes de mandar el update de una
     * instancia. Ese update ya paso por WriteThrough y lo que quedo sucio es lo
     * que la vista si acepta; sin esta marca el builder se volveria a desviar
     * por instancias y se llamaria a si mismo hasta quedarse sin stack.
     */
    public bool $toriiInstanceWrite = false;

    public function delete()
    {
        // El onDelete lo pone el scope de soft delete y convierte el borrado en
        // un update; ninguna tabla mapeada lo usa, pero si alguna lo usara este
        // desvio se lo comeria.
        if ($this->toriiInstanceWrite
            || isset($this->onDelete)
            || !WriteThrough::needsInstances($this->getModel(), 'delete')
        ) {
            return parent::delete();
        }

        $count = 0;

        foreach ($this->toriiTargets() as $model) {
            if ($model->delete() !== false) {
                ++$count;
            }
        }

        return $count;
    }

    public function update(array $values)
    {
        if ($this->toriiInstanceWrite) {
            // El SET final se arma aca, no en WriteThrough: Builder::update
            // agrega updated_at solo, calificado y despues de todo, asi que la
            // ultima pasada de limpieza tiene que ser esta.
            $values = WriteThrough::stripNonViewColumns($this->getModel(), $this->addUpdatedAtColumn($values));

            // Con todo filtrado no queda nada que mandar, y un SET vacio no
            // compila.
            return $values === [] ? 0 : $this->toBase()->update($values);
        }

        if (!WriteThrough::needsInstances($this->getModel(), 'update')) {
            return parent::update($values);
        }

        $count = 0;

        foreach ($this->toriiTargets() as $model) {
            if ($model->update($values)) {
                ++$count;
            }
        }

        return $count;
    }

    /**
     * Las filas que la operacion masiva iba a tocar, ya como modelos.
     */
    private function toriiTargets(): Collection
    {
        $query = clone $this;

        // Un select recortado (el lockForUpdate del job de pines pide una sola
        // columna) daria modelos sin clave y el save por instancia no sabria a
        // que fila pegarle.
        $query->getQuery()->columns = null;

        return $query->get();
    }
}
