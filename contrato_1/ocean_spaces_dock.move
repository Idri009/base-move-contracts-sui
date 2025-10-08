module marino_nft::especie {
    // Imports necesarios para Sui y strings
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::string::{Self, String};
    use std::vector;

    // --- ESTRUCTURAS PRINCIPALES ---

    // NFT principal: Representa una especie marina única con ID, nombre, rareza y atributos.
    public struct EspecieMarino has key, store {
        id: UID,
        nombre: String,
        descripcion: String,
        rareza: Rareza,
        atributos: vector<String>  // Ej: ["Profundidad: 100m", "Color: Azul"]
    }

    // Enum para niveles de rareza, cada uno con un valor numérico (para metadata).
    public enum Rareza has store, drop, copy {
        Comun(Comun),
        Rara(Rara),
        Epica(Epica),
        Legendaria(Legendaria)
    }

    // Estructuras para cada rareza con un "valor" (puede usarse para pricing futuro).
    public struct Comun has store, drop, copy {
        valor: u8  // Ej: 1
    }
    public struct Rara has store, drop, copy {
        valor: u8  // Ej: 5
    }
    public struct Epica has store, drop, copy {
        valor: u8  // Ej: 20
    }
    public struct Legendaria has store, drop, copy {
        valor: u8  // Ej: 100
    }

    // --- CONSTANTES DE ERROR ---
    #[error]
    const E_RAREZA_INVALIDA: vector<u8> = b"ERROR: Rareza invalida";
    #[error]
    const E_NOMBRE_VACIO: vector<u8> = b"ERROR: Nombre no puede estar vacio";

    // --- FUNCIONES PRINCIPALES ---

    // Mintea un nuevo NFT de especie marina.
    public fun mintear_especie(
        nombre: String,
        descripcion: String,
        rareza_tipo: u8,  // 0=Comun, 1=Rara, 2=Epica, 3=Legendaria
        atributos: vector<String>,
        ctx: &mut TxContext
    ) {
        assert!(!string::is_empty(&nombre), E_NOMBRE_VACIO);

        let rareza = match_rareza(rareza_tipo);
        let especie = EspecieMarino {
            id: object::new(ctx),
            nombre,
            descripcion,
            rareza,
            atributos
        };
        // Transfiere al creador.
        transfer::transfer(especie, tx_context::sender(ctx));
    }

    // Función helper para crear el enum Rareza.
    fun match_rareza(tipo: u8): Rareza {
        match tipo {
            0 => Rareza::comun(Comun { valor: 1 }),
            1 => Rareza::rara(Rara { valor: 5 }),
            2 => Rareza::epica(Epica { valor: 20 }),
            3 => Rareza::legendaria(Legendaria { valor: 100 }),
            _ => abort E_RAREZA_INVALIDA
        }
    }

    // Evoluciona el NFT: Agrega un atributo y actualiza rareza si es posible (ej: de Comun a Rara).
    public fun evolucionar_especie(
        especie: &mut EspecieMarino,
        nuevo_atributo: String,
        nueva_rareza_tipo: u8
    ) {
        vector::push_back(&mut especie.atributos, nuevo_atributo);
        especie.rareza = match_rareza(nueva_rareza_tipo);
    }

    // Obtiene el valor de rareza como string para display.
    public fun obtener_valor_rareza(especie: &EspecieMarino): String {
        let mut valor_str = string::utf8(b"Valor: ");
        match &especie.rareza {
            Rareza::comun(d) => valor_str = string::append(&mut valor_str, (d.valor as u64).into_string()),
            Rareza::rara(d) => valor_str = string::append(&mut valor_str, (d.valor as u64).into_string()),
            Rareza::epica(d) => valor_str = string::append(&mut valor_str, (d.valor as u64).into_string()),
            Rareza::legendaria(d) => valor_str = string::append(&mut valor_str, (d.valor as u64).into_string())
        };
        valor_str
    }

    // Elimina el NFT (solo el owner puede, en un contexto real agrega checks).
    public fun eliminar_especie(especie: EspecieMarino) {
        let EspecieMarino { id, nombre: _, descripcion: _, rareza: _, atributos: _ } = especie;
        object::delete(id);
    }
}