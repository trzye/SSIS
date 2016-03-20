-- Tworzenie bazy danych

USE master

IF EXISTS(SELECT * FROM sys.databases WHERE name='space_game_db')
	DROP DATABASE space_game_db

CREATE DATABASE space_game_db

GO

-- Wype³nianie bazy tabelami
--	Baza danych przechowuje przede wszystkim graczy oraz statki kosmiczne,
--	które s¹ do nich przypisane.

USE space_game_db

CREATE TABLE gracz(
	nick nvarchar(16) not null
		constraint pk_gracz primary key,
	haslo nvarchar(16) not null
)

CREATE TABLE statek(
	id_statku int not null identity 
		constraint pk_statek primary key,
	wlasciciel nvarchar(16) not null
		constraint fk_statek__gracz foreign key
		references gracz(nick),
	nazwa nvarchar(32) not null unique,
	zasieg int not null default 0,
	atak int not null default 0,
	obrona int not null default 0,
	szybkosc int not null default 0
)

-- reszta tabelek zgodnie z proœb¹ w instrukcji do projektu

CREATE TABLE usr(
	usr_id int not null identity
		constraint pk_usr primary key,
	email nvarchar(100) NULL,
	is_admin bit not null default 0
)

CREATE TABLE LOG(	
	msg nvarchar(256) not null,
	proc_name nvarchar(100) null,
	step_name nvarchar(100) null,
	row_id int not null identity 
		constraint pk_LOG primary key,
	entry_dt datetime not null default getdate()
)

CREATE TABLE imp( 
	imp_id int not null identity
		constraint pk_imp primary key,
	start_dt datetime not null default getdate(),
	end_dt datetime null, -- jak nie null to sie zakonczyl
	err_no int not null default 0, --liczba b³êdów
	usr_nam nvarchar(100) not null default user_name(),
	host nvarchar(100) not null default host_name()
)

CREATE TABLE imported_rows(
	imp_id int not null 
		constraint fk_ir_imp foreign key 
		references imp(imp_id), -- czyli link do importu 
	row_id int not null identity
		constraint pk_imported_rows primary key,
	imp_status nvarchar(20) not null 
		default 'not processed', -- not processed, imported, duplicated
	master_id nvarchar(16) null
		constraint fk_imported_rows__gracz foreign key 
		references gracz(nick),
	wlasciciel nvarchar(16) not null,
	nazwa nvarchar(32) not null,
	zasieg int not null,
	atak int not null,
	obrona int not null,
	szybkosc int not null
)

-- tabelka tymczasowa do importu

CREATE TABLE imp_tmp(
	wlasciciel nvarchar(16) not null,
	nazwa nvarchar(32) not null,
	zasieg int not null,
	atak int not null,
	obrona int not null,
	szybkosc int not null
)

-- stworzenie kilku graczy

INSERT INTO gracz VALUES('Gracz1', 'niezaszyfrowane1')
INSERT INTO gracz VALUES('Gracz2', 'jestemfajny')
INSERT INTO gracz VALUES('H@X00r', 'T5V|]NeH4$|_O')

-- dodanie kilku statków

INSERT INTO statek(wlasciciel, nazwa, szybkosc, atak, obrona, zasieg)
	VALUES('H@X00r', 'Sokó³ Milennium', 999, 999, 999, 999)

INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz1', 'Statek1a')
INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz1', 'Statek1b')

INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz2', 'Statek2a')
INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz2', 'Statek2b')
INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz2', 'Statek2c')

go

-- sprawdzenie czy siê poprawnie doda³o
/*
select * from statek
	join gracz on gracz.nick = statek.wlasciciel
	order by wlasciciel
*/
/* rezultat powinien byæ taki:
id_statku   wlasciciel       nazwa                            zasieg      atak        obrona      szybkosc    nick             haslo
----------- ---------------- -------------------------------- ----------- ----------- ----------- ----------- ---------------- ----------------
2           Gracz1           Statek1a                         0           0           0           0           Gracz1           niezaszyfrowane1
3           Gracz1           Statek1b                         0           0           0           0           Gracz1           niezaszyfrowane1
4           Gracz2           Statek2a                         0           0           0           0           Gracz2           jestemfajny
5           Gracz2           Statek2b                         0           0           0           0           Gracz2           jestemfajny
6           Gracz2           Statek2c                         0           0           0           0           Gracz2           jestemfajny
1           H@X00r           Sokó³ Milennium                  999         999         999         999         H@X00r           T5V|]NeH4$|_O
*/



-- Przepisywanie danych z imp_tmp do imported_rows

create procedure przepisanie_danych as
BEGIN
	insert into LOG(proc_name, msg, step_name) values('Przepisywanie danych do imported rows','OK', 'rozpoczêcie')
	insert into imp default values
	insert into 
		imported_rows(imp_id, wlasciciel, nazwa, zasieg, atak, obrona, szybkosc)
	select SCOPE_IDENTITY(), wlasciciel, nazwa, zasieg, atak, obrona, szybkosc
		from imp_tmp
	insert into LOG(proc_name, msg, step_name) values('Przepisywanie danych do imported rows','OK', 'zakoñczono')
END
GO

-- procesowanie danych z imported rows (o statusie 'not processed')
-- poprawne przypadki:
--	podany w³aœciciel istnieje -> wtedy dodajemy dla niego nowy statek
--	podany w³aœciciel nie istnieje -> dodajemy nowego gracza i nowy statek
-- mo¿liwe b³êdy:
--	statek o danej nazwie ju¿ istnieje 
--	(je¿eli tak, to nie powinniœmy dodawaæ nowego gracza!)

create procedure procesowanie_danych as
	insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK', 'rozpoczêcie')

	DECLARE @RowId int

	DECLARE MY_CURSOR CURSOR 
	  LOCAL STATIC READ_ONLY FORWARD_ONLY
	FOR 
	SELECT DISTINCT row_id
	FROM imported_rows
	WHERE imp_status = 'not processed'

	OPEN MY_CURSOR
	FETCH NEXT FROM MY_CURSOR INTO @RowId
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		
		IF
		(select s.nazwa from statek s
		 join imported_rows ir on ir.nazwa = s.nazwa
		 where ir.row_id = @RowId
		) is not null
		BEGIN 
			insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','ERROR - statek o podanej nazwie juz istnieje', 'Row: ' + CONVERT(varchar(10), @RowId) )
			update imported_rows
				set imp_status = 'duplicated'
			where imported_rows.row_id = @RowId
			update imp
				set err_no = err_no + 1
			where imp_id = 
				( select imp_id from imported_rows 
				  where row_id = @RowId)
		END
		ELSE
		BEGIN
			insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - nie istnieje statek o podanej nazwie', 'Row: ' + CONVERT(varchar(10), @RowId) )
			IF
			(select g.nick from gracz g
			 join imported_rows ir on ir.wlasciciel = g.nick
			 where ir.row_id = @RowId
			) is null
			BEGIN
				insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - podany gracz nie istnieje, tworzê nowego', 'Row: ' + CONVERT(varchar(10), @RowId) )
				insert into gracz values(
					(select wlasciciel from imported_rows 
					where row_id = @RowId),
					(select wlasciciel from imported_rows 
					where row_id = @RowId)
				)
				insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - gracz zosta³ utworzony', 'Row: ' + CONVERT(varchar(10), @RowId) )
			END
			insert into statek 
				select wlasciciel, nazwa, zasieg, atak, obrona, szybkosc
				from imported_rows where row_id = @RowId

			update imported_rows
				set imp_status = 'imported'
			where imported_rows.row_id = @RowId

			update imported_rows
				set master_id = wlasciciel
			where imported_rows.row_id = @RowId

			insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - statek zosta³ dodany', 'Row: ' + CONVERT(varchar(10), @RowId) )
		END

		
		FETCH NEXT FROM MY_CURSOR INTO @RowId
	END
	CLOSE MY_CURSOR
	DEALLOCATE MY_CURSOR

	update imp
		set end_dt = GETDATE()
	where end_dt is null

	insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK', 'zakoñczone')

go

select * from log
select * from imported_rows
select * from imp


execute procesowanie_danych




	EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'Adventure Works Administrator',
    @recipients = 'michal.jereczek@gmail.com',
    @body = 'The stored procedure finished successfully.',
    @subject = 'Automated Success Message' ;
