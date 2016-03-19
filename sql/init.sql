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
	err_no int not null default -1, -- in progres, 0 – finished 
	usr_nam nvarchar(100) not null default user_name(),
	host nvarchar(100) not null default host_name()
)CREATE TABLE imported_rows(
	imp_id int not null 
		constraint fk_ir_imp foreign key 
		references imp(imp_id), -- czyli link do importu 
	row_id int not null identity
		constraint pk_imported_rows primary key,
	imp_status nvarchar(20) not null 
		default 'not processed', -- not processed, imported, duplicated
	master_id nvarchar(16) not null
		constraint fk_imported_rows__gracz foreign key 
		references gracz(nick)
)-- tabelka tymczasowa do importuCREATE TABLE imp_tmp(
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

-- sprawdzenie czy siê poprawnie doda³o

select * from statek
	join gracz on gracz.nick = statek.wlasciciel
	order by wlasciciel

/* rezultat
id_statku   wlasciciel       nazwa                            zasieg      atak        obrona      szybkosc    nick             haslo
----------- ---------------- -------------------------------- ----------- ----------- ----------- ----------- ---------------- ----------------
2           Gracz1           Statek1a                         0           0           0           0           Gracz1           niezaszyfrowane1
3           Gracz1           Statek1b                         0           0           0           0           Gracz1           niezaszyfrowane1
4           Gracz2           Statek2a                         0           0           0           0           Gracz2           jestemfajny
5           Gracz2           Statek2b                         0           0           0           0           Gracz2           jestemfajny
6           Gracz2           Statek2c                         0           0           0           0           Gracz2           jestemfajny
1           H@X00r           Sokó³ Milennium                  999         999         999         999         H@X00r           T5V|]NeH4$|_O
*/