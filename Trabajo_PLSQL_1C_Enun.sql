drop table clientes cascade constraints;
drop table abonos   cascade constraints;
drop table eventos  cascade constraints;
drop table reservas	cascade constraints;

drop sequence seq_abonos;
drop sequence seq_eventos;
drop sequence seq_reservas;


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
    -- Comprobamos que el cliente existe
    select count(*) into v_cliente from clientes where NIF = arg_NIF_cliente;
   
    if v_cliente = 0 then
        raise_application_error(-20002, 'Cliente inexistente');
    end if;
    
    -- Comprobamos que el evento existe
    select count(*) into v_evento from eventos where nombre_evento = arg_nombre_evento;
    
    if v_evento = 0 then
        raise_application_error(-20003, 'El evento ' || arg_nombre_evento || ' no existe');
    end if;
    
    -- Comprobamos que el evento no haya pasado
    
    
    -- Comprobamos que el cliente disponga de saldo suficiente
    select saldo into v_saldo from abonos where cliente = arg_NIF_cliente;
    
    if v_saldo <= 0 then
        raise_application_error(-20004, 'Saldo en abono insuficiente');
    end if;
    
    -- Comprobar que el evento tiene asientos disponibles
    select asientos_disponibles into v_asientos from eventos where nombre_evento = arg_nombre_evento;
    
    if v_asientos <= 0 then 
        raise_application_error(-20005, 'No hay asientos libres para el evento' || arg_nombre_evento || '.');
    end if;
    
    -- Comprobar que la fecha de los eventos es correcta
    select fecha into v_fecha from eventos where nombre_evento = arg_nombre_evento;
    
    if v_fecha != arg_fecha then
        raise_application_error(-20006, 'La fecha de reserva del evento ' || arg_nombre_evento || ' es incorrecta');
    end if;
    
    
    -- Obtenemos los valores de id de evento y de abono
    select id_evento into v_id_evento from eventos where nombre_evento = arg_nombre_evento and fecha = arg_fecha;
    select id_abono into v_id_abono from abonos where cliente =  arg_NIF_cliente;
    
    -- Realizamos la reserva
    insert into reservas
    values (seq_reservas.nextval, arg_NIF_cliente, v_id_evento, v_id_abono, arg_fecha);
    
    -- Descontamos en una unidad el número de plazas disponibles del evento
    update eventos
    set asientos_disponibles = asientos_disponibles - 1
    where nombre_evento = arg_nombre_evento;
    
    -- Decrementamos en una unidad el saldo del abono del cliente correspondiente
    update abonos
    set saldo = saldo - 1
    where cliente = arg_NIF_cliente;
  
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- * P4.1
--
-- * P4.2
--
-- * P4.3
--
-- * P4.4
--
-- * P4.5
-- 


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
    
    insert into eventos values ( seq_eventos.nextval, 'concierto_la_moda', date '2023-6-27', 200);
    insert into eventos values ( seq_eventos.nextval, 'teatro_impro', date '2023-7-1', 50);

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
  end;
  
  
  --caso 2 Evento pasado
  begin
    inicializa_test;
  end;
  
  --caso 3 Evento inexistente
  begin
    inicializa_test;
  end;
  

  --caso 4 Cliente inexistente  
  begin
    inicializa_test;
  end;
  
  --caso 5 El cliente no tiene saldo suficiente
  begin
    inicializa_test;
  end;

  
end;
/


set serveroutput on;
exec test_reserva_evento;

-- Llamamos al procedimiento reservar_evento para hacer un par de reservas
begin
    reservar_evento('12345678A', 'concierto_la_moda', date '2023-6-27');
end;
/

begin
    reservar_evento('12345678A', 'teatro_impro', date '2023-7-1');
end;
/

-- Hacemos nuevas reservas para comprobar el funcionamiento de las excepciones
-- Cliente inexistente
begin
    reservar_evento('12345678B', 'concierto_la_moda', date '2023-6-27');
end;
/

-- Evento inexistente
begin
    reservar_evento('12345678A', 'concierto_las_modas', date '2023-6-27');
end;
/

-- Cliente sin saldo del abono suficiente
begin
    reservar_evento('11111111B', 'concierto_la_moda', date '2023-6-27');
end;
/


-- Utilizamos selects para ver los resultados de las reservas en las tablas
select * from clientes; 
select * from abonos;
select * from eventos;
select * from reservas;
