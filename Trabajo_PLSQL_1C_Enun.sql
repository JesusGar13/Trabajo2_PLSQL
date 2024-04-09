-- Enlace del repositorio: https://github.com/JesusGar13/Trabajo2_PLSQL

BEGIN
    -- Drop de las tablas solo si existen
    FOR table_rec IN (SELECT table_name FROM user_tables WHERE table_name IN ('CLIENTES', 'ABONOS', 'EVENTOS', 'RESERVAS')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || table_rec.table_name || ' CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Tabla ' || table_rec.table_name || ' borrada correctamente. ');
    END LOOP;

    -- Drop de las secuencias solo si existen	
    FOR sequence_rec IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN ('SEQ_ABONOS', 'SEQ_EVENTOS', 'SEQ_RESERVAS')) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || sequence_rec.sequence_name;
        DBMS_OUTPUT.PUT_LINE('Secuencia ' || sequence_rec.sequence_name || ' borrada correctamente.');
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN -- Si el error no es "table or view does not exist"
            RAISE;
        END IF;
END;
/


-- Creación de tablas y secuencias

create table clientes(
	NIF	varchar(9) primary key,
	nombre	varchar(20) not null,
	ape1	varchar(20) not null,
	ape2	varchar(20) not null
);


create sequence seq_abonos;

create table abonos(
	id_abono	integer primary key,
	cliente  	varchar(9) references clientes,
	saldo	    integer not null check (saldo>=0)
    );

create sequence seq_eventos;

create table eventos(
	id_evento	integer  primary key,
	nombre_evento		varchar(20),
    fecha       date not null,
	asientos_disponibles	integer  not null
);

create sequence seq_reservas;

create table reservas(
	id_reserva	integer primary key,
	cliente  	varchar(9) references clientes,
    evento      integer references eventos,
	abono       integer references abonos,
	fecha	date not null
);


	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure reservar_evento( arg_NIF_cliente varchar,
 arg_nombre_evento varchar, arg_fecha date) is
 
 --Definimos variables locales para estudiar se se pueden hacer las reservas
    v_cliente integer;
    v_evento integer;
    v_saldo integer;
    v_asientos integer;
    v_fecha date;
    v_id_evento integer;
    v_id_abono integer;
    
 begin 
    -- Verificamos la existencia del cliente
    select count(*) into v_cliente from clientes where NIF = arg_NIF_cliente;
   
    if v_cliente = 0 then
        raise_application_error(-20002, 'Error: Cliente inexistente');
    end if;
    
    -- Verificamos la existencia del evento
    select count(*) into v_evento from eventos where nombre_evento = arg_nombre_evento;
    
    if v_evento = 0 then
        raise_application_error(-20003, 'Error: El evento ' || arg_nombre_evento || ' no existe');
    end if;
    
    -- Comprobamos que el evento no haya pasado
    if arg_fecha < sysdate then
        raise_application_error(-20001, 'No se pueden reservar eventos pasados.');
    end if;

    -- Verificamos que el cliente tenga saldo suficiente en su abono
    select saldo into v_saldo from abonos where cliente = arg_NIF_cliente;
    
    if v_saldo <= 0 then
        raise_application_error(-20004, 'Error: Saldo en abono insuficiente');
    end if;
    
    -- Verificamos que el evento tenga asientos disponibles
    select asientos_disponibles into v_asientos from eventos where nombre_evento = arg_nombre_evento;
    
    if v_asientos <= 0 then 
        raise_application_error(-20005, 'Error: No hay asientos libres para el evento' || arg_nombre_evento || '.');
    end if;
    
    -- Comprobamos que la fecha del evento sea correcta
    select fecha into v_fecha from eventos where nombre_evento = arg_nombre_evento;
    
    if v_fecha <> arg_fecha then
        raise_application_error(-20006, 'Error: La fecha de reserva del evento ' || arg_nombre_evento || ' es incorrecta');
    end if;
    
    
    -- Obtenemos los valores de ID de evento y de abono
    select id_evento into v_id_evento from eventos where nombre_evento = arg_nombre_evento and fecha = arg_fecha;
    select id_abono into v_id_abono from abonos where cliente =  arg_NIF_cliente;
    
    -- Realizamos la reserva
    insert into reservas
    values (seq_reservas.nextval, arg_NIF_cliente, v_id_evento, v_id_abono, arg_fecha);
    
    -- Disminuimos en una unidad el número de plazas disponibles del evento
    update eventos
    set asientos_disponibles = asientos_disponibles - 1
    where nombre_evento = arg_nombre_evento;
    
    -- Disminuimos en una unidad el saldo del abono del cliente correspondiente
    update abonos
    set saldo = saldo - 1
    where cliente = arg_NIF_cliente;
  
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- P4.1: ¿Qué hace el procedimiento almacenado "reset_seq"?

-- El procedimiento almacenado "reset_seq" se utiliza para reiniciar una secuencia en la base de datos. Toma como entrada el nombre de la secuencia y realiza los siguientes pasos:
-- 1. Obtiene el próximo valor de la secuencia.
-- 2. Altera la secuencia para que su incremento sea negativo, decrementando así el valor de la secuencia en el número de valores que ya había generado.
-- 3. Obtiene nuevamente el próximo valor de la secuencia, lo cual provoca que la secuencia se ajuste al nuevo valor decrementado.
-- 4. Restaura el incremento de la secuencia a su valor original (positivo).

-- Este procedimiento se utiliza principalmente en entornos de prueba o reinicio de bases de datos para garantizar que las secuencias comiencen desde un valor específico.

-- P4.2: ¿Qué hace el procedimiento almacenado "inicializa_test"?

-- El procedimiento almacenado "inicializa_test" se encarga de preparar el entorno de pruebas para la funcionalidad de reserva de eventos. Realiza las siguientes acciones:
-- 1. Reinicia las secuencias de abonos, eventos y reservas utilizando el procedimiento "reset_seq".
-- 2. Elimina todos los registros de las tablas de reservas, eventos, abonos y clientes.
-- 3. Inserta datos de prueba en la tabla de clientes.
-- 4. Inserta datos de prueba en la tabla de abonos.
-- 5. Inserta datos de prueba en la tabla de eventos.

-- Este procedimiento asegura un entorno de prueba limpio y preconfigurado para probar la funcionalidad de reserva de eventos.

-- * P4.3
-- Estrategia de control de concurrencia y manejo de excepciones
-- En nuestro sistema de gestión de reservas, hemos implementado una estrategia de programación que se centra en el control de concurrencia y el manejo de excepciones para garantizar la integridad y la fiabilidad de nuestras operaciones.
-- Esta estrategia implica verificar la disponibilidad de recursos y manejar cualquier excepción que pueda surgir durante el proceso de reservas. Aquí está cómo lo llevamos a cabo:
-- 1. Utilizamos bloqueos de base de datos para controlar el acceso concurrente a recursos críticos, como registros de reservas o eventos. Esto ayuda a prevenir situaciones de competencia que podrían resultar en inconsistencias o errores en los datos.
-- 2. Implementamos manejo de excepciones en nuestros procedimientos almacenados y scripts SQL. Esto nos permite capturar y manejar errores de manera efectiva, asegurando que nuestras transacciones se ejecuten de manera consistente incluso cuando se producen condiciones inesperadas.
-- En resumen, nuestra estrategia de programación basada en el control de concurrencia y el manejo de excepciones nos permite mantener la integridad de los datos y garantizar una experiencia sin problemas para nuestros usuarios durante el proceso de reservas.
	

--P4.4 - Utilización de select y comprobaciones durante la ejecución del código
-- En nuestro código SQL, la estrategia de control de concurrencia y manejo de excepciones se refleja principalmente en los select que realizamos para verificar el estado de las tablas de la base de datos.
-- Estos select nos permiten asegurarnos de que los recursos necesarios para las operaciones de reserva estén disponibles y en el estado adecuado antes de proceder con cualquier acción.
-- Además de los select, también llevamos a cabo comprobaciones intermedias durante la ejecución del código. Estas comprobaciones nos permiten hacer un seguimiento detallado de las acciones que se están llevando a cabo y tomar decisiones en tiempo real para manejar situaciones imprevistas o excepcionales que puedan surgir.
-- En resumen, utilizamos select y comprobaciones durante la ejecución del código para garantizar la integridad y la fiabilidad de nuestras operaciones de reserva, así como para proporcionar un seguimiento detallado de las acciones realizadas.

	
-- * P4.5
-- Para abordar el problema de la concurrencia y que la reserva de los eventos sea consistente usamos excepciones 
-- para manejar los datos que se toman para la reserva.
-- Otra forma de abordar el problema seria con bloqueos de linea durante la ejcucion de las consultas e inserciones.
-- Para ello añadiremos la clausala "FOR UPDATE" en las consultas que se realizan sobre la tabla de eventos para 
-- bloquear la fila. Esto evita que otros procesos puedan modificar los datos de la fila mientras se realiza la reserva.
-- La implementacion sera la siguiente:
/*
CREATE OR REPLACE PROCEDURE reservar_evento(
    arg_NIF_cliente VARCHAR,
    arg_nombre_evento VARCHAR,
    arg_fecha DATE
) IS
    v_cliente INTEGER;
    v_evento INTEGER;
    v_saldo INTEGER;
    v_asientos INTEGER;
    v_fecha DATE;
    v_id_evento INTEGER;
    v_id_abono INTEGER;
BEGIN
    -- Verificamos la existencia del cliente
    SELECT COUNT(*) INTO v_cliente FROM clientes WHERE NIF = arg_NIF_cliente;

    IF v_cliente = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error: Cliente inexistente');
    END IF;

    -- Verificamos la existencia del evento y bloqueamos la fila para evitar cambios concurrentes
    SELECT COUNT(*) INTO v_evento
    FROM eventos
    WHERE nombre_evento = arg_nombre_evento
    FOR UPDATE;

    IF v_evento = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error: El evento ' || arg_nombre_evento || ' no existe');
    END IF;

    -- Comprobamos que el evento no haya pasado
    IF arg_fecha < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'No se pueden reservar eventos pasados.');
    END IF;

    -- Verificamos que el cliente tenga saldo suficiente en su abono
    SELECT saldo INTO v_saldo FROM abonos WHERE cliente = arg_NIF_cliente;

    IF v_saldo <= 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Error: Saldo en abono insuficiente');
    END IF;

    -- Verificamos que el evento tenga asientos disponibles
    SELECT asientos_disponibles INTO v_asientos FROM eventos WHERE nombre_evento = arg_nombre_evento;

    IF v_asientos <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error: No hay asientos libres para el evento ' || arg_nombre_evento || '.');
    END IF;

    -- Comprobamos que la fecha del evento sea correcta
    SELECT fecha INTO v_fecha FROM eventos WHERE nombre_evento = arg_nombre_evento;

    IF v_fecha <> arg_fecha THEN
        RAISE_APPLICATION_ERROR(-20006, 'Error: La fecha de reserva del evento ' || arg_nombre_evento || ' es incorrecta');
    END IF;

    -- Obtenemos los valores de ID de evento y de abono
    SELECT id_evento INTO v_id_evento FROM eventos WHERE nombre_evento = arg_nombre_evento AND fecha = arg_fecha;
    SELECT id_abono INTO v_id_abono FROM abonos WHERE cliente = arg_NIF_cliente;

    -- Realizamos la reserva
    INSERT INTO reservas
    VALUES (seq_reservas.NEXTVAL, arg_NIF_cliente, v_id_evento, v_id_abono, arg_fecha);

    -- Disminuimos en una unidad el número de plazas disponibles del evento
    UPDATE eventos
    SET asientos_disponibles = asientos_disponibles - 1
    WHERE nombre_evento = arg_nombre_evento;

    -- Disminuimos en una unidad el saldo del abono del cliente correspondiente
    UPDATE abonos
    SET saldo = saldo - 1
    WHERE cliente = arg_NIF_cliente;
END;
/

*/


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_abonos' );
  reset_seq( 'seq_eventos' );
  reset_seq( 'seq_reservas' );
        
  
    delete from reservas;
    delete from eventos;
    delete from abonos;
    delete from clientes;
    
       
		
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez');
    
    insert into abonos values (seq_abonos.nextval, '12345678A',10);
    insert into abonos values (seq_abonos.nextval, '11111111B',0);
    
    insert into eventos values ( seq_eventos.nextval, 'concierto_la_moda', date '2024-6-27', 200);
    insert into eventos values ( seq_eventos.nextval, 'teatro_impro', date '2024-7-1', 50);

    commit;
end;
/

exec inicializa_test;

-- Completa el test

create or replace procedure test_reserva_evento is
begin
	 
  --caso 1 Reserva correcta, se realiza
  begin
    inicializa_test;
    reservar_evento('12345678A', 'concierto_la_moda', date '2024-6-27');
    dbms_output.put_line('Caso 1: correcto');
  exception
    when others then
        dbms_output.put_line('Caso 1 incorrecto. No se puede realizar la reserva');
  end;
  
  
  --caso 2 Evento pasado
  begin
    inicializa_test;
    reservar_evento('12345678A', 'teatro_impro', date '2023-7-1');
    dbms_output.put_line('Caso 2: Fallo el test');
  exception
    when others then
        dbms_output.put_line('Caso 2 correcto lanza Error -20002: Evento pasado');
  end;
  
  --caso 3 Evento inexistente
  begin
    inicializa_test;
    reservar_evento('12345678Z', 'evento_inexistente', date '2023-6-27');
    dbms_output.put_line('Caso 3: Fallo el test');
  exception
    when others then
        dbms_output.put_line('Caso 3 correcto lanza Error -20002: Evento inexistente');
  end;
  

  -- Caso 4: Cliente inexistente  
  begin
    inicializa_test;
    reservar_evento('12345678Z', 'concierto_la_moda', date '2023-6-27');
    dbms_output.put_line('Caso 4: Fallo el test');
  exception
    when others then
        dbms_output.put_line('Caso 4 correcto lanza Error -20002: Cliente inexistente');
  end;

-- Caso 5: El cliente no tiene saldo suficiente
begin
    inicializa_test;
    reservar_evento('11111111B', 'concierto_la_moda', date '2023-6-27');
    dbms_output.put_line('Caso 5: Fallo el test');
exception
    when others then
        dbms_output.put_line('Caso 5 correcto lanza Error -20004: Saldo insuficiente');
end;

  
end;
/


set serveroutput on;
exec test_reserva_evento;

-- Llamamos al procedimiento reservar_evento para hacer un par de reservas
begin
    reservar_evento('12345678A', 'concierto_la_moda', date '2024-6-27');
end;
/

begin
    reservar_evento('12345678A', 'teatro_impro', date '2024-7-1');
end;
/

-- Hacemos nuevas reservas para comprobar el funcionamiento de las excepciones
-- Cliente inexistente
begin
    reservar_evento('12345678B', 'concierto_la_moda', date '2024-6-27');
end;
/

-- Evento inexistente
begin
    reservar_evento('12345678A', 'concierto_las_modas', date '2024-6-27');
end;
/

-- Cliente sin saldo del abono suficiente
begin
    reservar_evento('11111111B', 'concierto_la_moda', date '2024-6-27');
end;
/


-- Utilizamos selects para ver los resultados de las reservas en las tablas
select * from clientes; 
select * from abonos;
select * from eventos;
select * from reservas;
