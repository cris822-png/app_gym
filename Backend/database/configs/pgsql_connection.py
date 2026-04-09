import psycopg2
from psycopg2 import pool
import threading

# Lock para evitar que dos hilos creen el mismo pool a la vez
_pool_lock = threading.Lock()
_pools = {}
_conn_to_pool = {}

def get_pool(host, database, user, password):
    pool_key = f"{host}:{database}"
    
    # Doble comprobación con lock para eficiencia
    if pool_key not in _pools:
        with _pool_lock:
            if pool_key not in _pools:
                try:
                    _pools[pool_key] = psycopg2.pool.ThreadedConnectionPool(
                        minconn=1,
                        maxconn=30,
                        host=host, 
                        database=database, 
                        user=user, 
                        password=password
                    )
                    print(f"✅ Pool creado: {database}")
                except Exception as e:
                    print(f"❌ Error al crear pool: {e}")
                    return None
    return _pools[pool_key]

def connect_bbdd_pgsql(host, database, user, password):
    db_pool = get_pool(host, database, user, password)
    if not db_pool:
        return None
    
    try:
        conn = db_pool.getconn()
        # Importante: No ponemos el id en el dict hasta estar seguros de tener la conn
        _conn_to_pool[id(conn)] = db_pool
        return conn
    except Exception as e:
        print(f"Error al obtener conexión: {e}")
        return None

def release_connection(conn):
    if not conn:
        return
        
    db_pool = _conn_to_pool.pop(id(conn), None)
    if db_pool:
        try:
            # putconn devuelve la conexión al pool, NO la cierra
            db_pool.putconn(conn)
        except Exception as e:
            print(f"Error devolviendo conexión: {e}")
    else:
        # Si no está en el registro, la cerramos por seguridad
        conn.close()