module snacks::mercado {
    // Imports necesarios para Sui
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::vec_map::{Self, VecMap};
    use sui::string::{Self, String, utf8};
    use std::vector;

    // --- ESTRUCTURAS PRINCIPALES ---

    // Mercado principal: Registra vendedores y clientes.
    public struct MercadoSnacks has key, store {
        id: UID,
        nombre_mercado: String,
        vendedores: VecMap<u16, Vendedor>, // ID vendedor -> Vendedor
        clientes: VecMap<u16, Cliente>     // ID cliente -> Cliente
    }

    // Estructura para vendedores con inventario de snacks.
    public struct Vendedor has store, drop, copy {
        nombre: String,
        inventario: VecMap<String, u64>, // Tipo de snack (ej: "Cheetos") -> Cantidad
        ventas_totales: u64              // Total vendido (unidades)
    }

    // Estructura para clientes con nivel de lealtad y historial de compras.
    public struct Cliente has store, drop, copy {
        nombre: String,
        nivel: Nivel,
        compras_totales: u64,           // Total comprado (unidades)
        historial_compras: vector<String> // Registro de compras
    }

    // Enum para niveles de lealtad de clientes.
    public enum Nivel has store, drop, copy {
        Casual(Casual),
        Fanatico(Fanatico),
        Leyenda(Leyenda)
    }

    public struct Casual has store, drop, copy { descuento: u8 }   // 0%
    public struct Fanatico has store, drop, copy { descuento: u8 } // 5%
    public struct Leyenda has store, drop, copy { descuento: u8 }  // 15%

    // --- CONSTANTES DE ERROR ---
    #[error]
    const E_ID_VENDEDOR_EXISTE: vector<u8] = b"ERROR: ID de vendedor ya existe";
    #[error]
    const E_ID_VENDEDOR_NO_EXISTE: vector<u8] = b"ERROR: ID de vendedor no existe";
    #[error]
    const E_ID_CLIENTE_EXISTE: vector<u8] = b"ERROR: ID de cliente ya existe";
    #[error]
    const E_ID_CLIENTE_NO_EXISTE: vector<u8] = b"ERROR: ID de cliente no existe";
    #[error]
    const E_SNACK_NO_DISPONIBLE: vector<u8] = b"ERROR: Snack no disponible o sin stock";
    #[error]
    const E_CANTIDAD_INVALIDA: vector<u8] = b"ERROR: Cantidad debe ser mayor a 0";

    // --- FUNCIONES PRINCIPALES ---

    // Crea un nuevo mercado de snacks.
    public fun crear_mercado(nombre: String, ctx: &mut TxContext) {
        let mercado = MercadoSnacks {
            id: object::new(ctx),
            nombre_mercado: nombre,
            vendedores: vec_map::empty(),
            clientes: vec_map::empty()
        };
        transfer::transfer(mercado, tx_context::sender(ctx));
    }

    // Registra un nuevo vendedor con un inventario vacío.
    public fun registrar_vendedor(mercado: &mut MercadoSnacks, nombre: String, id_vendedor: u16) {
        assert!(!vec_map::contains(&mercado.vendedores, &id_vendedor), E_ID_VENDEDOR_EXISTE);

        let vendedor = Vendedor {
            nombre,
            inventario: vec_map::empty(),
            ventas_totales: 0
        };
        vec_map::insert(&mut mercado.vendedores, id_vendedor, vendedor);
    }

    // Registra un nuevo cliente con nivel inicial Casual.
    public fun registrar_cliente(mercado: &mut MercadoSnacks, nombre: String, id_cliente: u16) {
        assert!(!vec_map::contains(&mercado.clientes, &id_cliente), E_ID_CLIENTE_EXISTE);

        let cliente = Cliente {
            nombre,
            nivel: Nivel::casual(Casual { descuento: 0 }),
            compras_totales: 0,
            historial_compras: vector::empty()
        };
        vec_map::insert(&mut mercado.clientes, id_cliente, cliente);
    }

    // Agrega stock de un snack al inventario de un vendedor.
    public fun agregar_stock(
        mercado: &mut MercadoSnacks,
        id_vendedor: u16,
        tipo_snack: String, // Ej: "Cheetos", "Papas Fritas"
        cantidad: u64
    ) {
        assert!(vec_map::contains(&mercado.vendedores, &id_vendedor), E_ID_VENDEDOR_NO_EXISTE);
        assert!(cantidad > 0, E_CANTIDAD_INVALIDA);

        let vendedor = vec_map::get_mut(&mut mercado.vendedores, &id_vendedor);
        if (vec_map::contains(&vendedor.inventario, &tipo_snack)) {
            let stock_actual = vec_map::get_mut(&mut vendedor.inventario, &tipo_snack);
            *stock_actual = *stock_actual + cantidad;
        } else {
            vec_map::insert(&mut vendedor.inventario, tipo_snack, cantidad);
        };
    }

    // Procesa una compra de snacks, aplicando descuento según nivel de lealtad.
    public fun comprar_snack(
        mercado: &mut MercadoSnacks,
        id_vendedor: u16,
        id_cliente: u16,
        tipo_snack: String,
        cantidad: u64
    ): String {
        assert!(vec_map::contains(&mercado.vendedores, &id_vendedor), E_ID_VENDEDOR_NO_EXISTE);
        assert!(vec_map::contains(&mercado.clientes, &id_cliente), E_ID_CLIENTE_NO_EXISTE);
        assert!(cantidad > 0, E_CANTIDAD_INVALIDA);

        let vendedor = vec_map::get_mut(&mut mercado.vendedores, &id_vendedor);
        assert!(vec_map::contains(&vendedor.inventario, &tipo_snack), E_SNACK_NO_DISPONIBLE);
        let stock = vec_map::get_mut(&mut vendedor.inventario, &tipo_snack);
        assert!(*stock >= cantidad, E_SNACK_NO_DISPONIBLE);

        let cliente = vec_map::get_mut(&mut mercado.clientes, &id_cliente);

        // Calcula costo con descuento
        let mut costo = cantidad;
        let descuento = match &cliente.nivel {
            Nivel::casual(d) => d.descuento,
            Nivel::fanatico(d) => d.descuento,
            Nivel::leyenda(d) => d.descuento
        };
        costo = costo * (100 - (descuento as u64)) / 100;

        // Actualiza inventario y ventas
        *stock = *stock - cantidad;
        vendedor.ventas_totales = vendedor.ventas_totales + cantidad;

        // Actualiza cliente
        cliente.compras_totales = cliente.compras_totales + cantidad;
        let mut compra_registro = utf8(b"Compro ");
        compra_registro = string::append(&mut compra_registro, (cantidad as u64).into_string());
        compra_registro = string::append(&mut compra_registro, utf8(b" "));
        compra_registro = string::append(&mut compra_registro, tipo_snack);
        vector::push_back(&mut cliente.historial_compras, compra_registro);

        // Sube nivel si corresponde
        if (cliente.compras_totales >= 100 && !es_leyenda(&cliente.nivel)) {
            cliente.nivel = Nivel::fanatico(Fanatico { descuento: 5 });
        } else if (cliente.compras_totales >= 500) {
            cliente.nivel = Nivel::leyenda(Leyenda { descuento: 15 });
        };

        // Retorna mensaje de compra
        let mut mensaje = utf8(b"Compra de ");
        mensaje = string::append(&mut mensaje, (cantidad as u64).into_string());
        mensaje = string::append(&mut mensaje, utf8(b" "));
        mensaje = string::append(&mut mensaje, tipo_snack);
        mensaje = string::append(&mut mensaje, utf8(b", Costo: "));
        mensaje = string::append(&mut mensaje, (costo as u64).into_string());
        mensaje = string::append(&mut mensaje, utf8(b", Descuento: "));
        mensaje = string::append(&mut mensaje, (descuento as u64).into_string());
        mensaje = string::append(&mut mensaje, utf8(b"%"));
        mensaje
    }

    // Helper: Verifica si el cliente es Leyenda
    fun es_leyenda(nivel: &Nivel): bool {
        match nivel {
            Nivel::leyenda(_) => true,
            _ => false
        }
    }

    // Elimina un vendedor
    public fun eliminar_vendedor(mercado: &mut MercadoSnacks, id_vendedor: u16) {
        assert!(vec_map::contains(&mercado.vendedores, &id_vendedor), E_ID_VENDEDOR_NO_EXISTE);
        vec_map::remove(&mut mercado.vendedores, &id_vendedor);
    }

    // Elimina un cliente
    public fun eliminar_cliente(mercado: &mut MercadoSnacks, id_cliente: u16) {
        assert!(vec_map::contains(&mercado.clientes, &id_cliente), E_ID_CLIENTE_NO_EXISTE);
        vec_map::remove(&mut mercado.clientes, &id_cliente);
    }

    // Elimina el mercado entero
    public fun eliminar_mercado(mercado: MercadoSnacks) {
        let MercadoSnacks { id, nombre_mercado: _, vendedores: _, clientes: _ } = mercado;
        object::delete(id);
    }

    // Consulta el estado de un cliente (nivel, compras totales)
    public fun obtener_estado_cliente(mercado: &MercadoSnacks, id_cliente: u16): String {
        assert!(vec_map::contains(&mercado.clientes, &id_cliente), E_ID_CLIENTE_NO_EXISTE);

        let cliente = vec_map::get(&mercado.clientes, &id_cliente);
        let mut estado = utf8(b"Cliente: ");
        estado = string::append(&mut estado, cliente.nombre);
        estado = string::append(&mut estado, utf8(b", Nivel: "));
        match &cliente.nivel {
            Nivel::casual(_) => estado = string::append(&mut estado, utf8(b"Casual")),
            Nivel::fanatico(_) => estado = string::append(&mut estado, utf8(b"Fanatico")),
            Nivel::leyenda(_) => estado = string::append(&mut estado, utf8(b"Leyenda"))
        };
        estado = string::append(&mut estado, utf8(b", Compras Totales: "));
        estado = string::append(&mut estado, (cliente.compras_totales as u64).into_string());
        estado
    }
}