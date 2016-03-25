-- Tworzenie serwisu mailowego

    
/* Usuwanie danych o serwisie
	EXEC msdb.dbo.sysmail_delete_profile_sp
	  @profile_name = 'Error mail service'

	EXEC msdb.dbo.sysmail_delete_account_sp
	  @account_name = 'Error mail service: Space Game'
*/

    EXEC msdb.dbo.sysmail_add_profile_sp
      @profile_name = 'Error mail service',
      @description = 'Sending emails to admins'

	
    EXEC msdb.dbo.sysmail_add_account_sp
      @account_name = 'Error mail service: Space Game',
      @description = 'mail used to send informations about errors',
      @email_address = 'space.game.noreply@gmail.com',
      @display_name = 'Error mail service: Space Game',
      @mailserver_name = 'smtp.gmail.com',
      @port = 587,
      @use_default_credentials = 0,
	  @username = 'space.game.noreply@gmail.com',
	  @password = 'spacegamenoreply',
	  @enable_ssl = 1
    
    EXEC msdb.dbo.sysmail_add_profileaccount_sp 
      @profile_name = 'Error mail service',
      @account_name = 'Error mail service: Space Game',
      @sequence_number = 1

/* Testowy email 
	USE [msdb]
    EXEC sp_send_dbmail
      @profile_name = 'Error mail service',
      @recipients = 'michal.jereczek@gmail.com',
      @subject = 'Test',
      @body = 'Test maila, nie odpisywać :-)'
*/

GO

-- Tworzenie bazy danych

USE master

IF EXISTS(SELECT * FROM sys.databases WHERE name='space_game_db')
	DROP DATABASE space_game_db

CREATE DATABASE space_game_db

GO

-- Wypełnianie bazy tabelami
--	Baza danych przechowuje przede wszystkim graczy oraz statki kosmiczne,
--	które są do nich przypisane.

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

-- reszta tabelek zgodnie z prośbą w instrukcji do projektu

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
	err_no int not null default 0, --liczba błędów
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
	VALUES('H@X00r', 'Sokół Milennium', 999, 999, 999, 999)

INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz1', 'Statek1a')

INSERT INTO statek(wlasciciel, nazwa) VALUES('Gracz2', 'Statek2a')

go

-- sprawdzenie czy się poprawnie dodało
/*
select * from statek
	join gracz on gracz.nick = statek.wlasciciel
	order by wlasciciel
*/
/* rezultat powinien być taki:
id_statku   wlasciciel       nazwa                            zasieg      atak        obrona      szybkosc    nick             haslo
----------- ---------------- -------------------------------- ----------- ----------- ----------- ----------- ---------------- ----------------
2           Gracz1           Statek1a                         0           0           0           0           Gracz1           niezaszyfrowane1
3           Gracz1           Statek1b                         0           0           0           0           Gracz1           niezaszyfrowane1
4           Gracz2           Statek2a                         0           0           0           0           Gracz2           jestemfajny
5           Gracz2           Statek2b                         0           0           0           0           Gracz2           jestemfajny
6           Gracz2           Statek2c                         0           0           0           0           Gracz2           jestemfajny
1           H@X00r           Sokół Milennium                  999         999         999         999         H@X00r           T5V|]NeH4$|_O
*/



-- Przepisywanie danych z imp_tmp do imported_rows

create procedure przepisanie_danych as
BEGIN
	insert into LOG(proc_name, msg, step_name) values('Przepisywanie danych do imported rows','OK', 'rozpoczęcie')
	insert into imp default values
	insert into 
		imported_rows(imp_id, wlasciciel, nazwa, zasieg, atak, obrona, szybkosc)
	select SCOPE_IDENTITY(), wlasciciel, nazwa, zasieg, atak, obrona, szybkosc
		from imp_tmp
	insert into LOG(proc_name, msg, step_name) values('Przepisywanie danych do imported rows','OK', 'zakończono')
END
GO

-- procesowanie danych z imported rows (o statusie 'not processed')
-- poprawne przypadki:
--	podany właściciel istnieje -> wtedy dodajemy dla niego nowy statek
--	podany właściciel nie istnieje -> dodajemy nowego gracza i nowy statek
-- możliwe błędy:
--	statek o danej nazwie już istnieje 
--	(jeżeli tak, to nie powinniśmy dodawać nowego gracza!)

create procedure procesowanie_danych as
	insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK', 'rozpoczęcie')

	DECLARE @RowId int

	DECLARE MY_CURSOR CURSOR 
	  LOCAL STATIC READ_ONLY FORWARD_ONLY
	FOR 
	SELECT DISTINCT row_id
	FROM imported_rows
	WHERE imp_status = 'not processed'

	-- Pętla, w której procesujemy kolejno nieprzeprocesowane rekordy
	OPEN MY_CURSOR
	FETCH NEXT FROM MY_CURSOR INTO @RowId
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		
		-- Sprawdzam czy statek już istnieje, jak tak to zgłaszam błąd
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
		-- w innym wypadku procesujemy taki statek
		ELSE
		BEGIN
			-- sprawdzam czy istnieje gracz dla podanego statku
			insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - nie istnieje statek o podanej nazwie', 'Row: ' + CONVERT(varchar(10), @RowId) )
			IF
			(select g.nick from gracz g
			 join imported_rows ir on ir.wlasciciel = g.nick
			 where ir.row_id = @RowId
			) is null
			-- jeżeli nie istnieje to dodaję go
			BEGIN
				insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - podany gracz nie istnieje, tworzę nowego', 'Row: ' + CONVERT(varchar(10), @RowId) )
				insert into gracz values(
					(select wlasciciel from imported_rows 
					where row_id = @RowId),
					(select wlasciciel from imported_rows 
					where row_id = @RowId)
				)
				insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - gracz został utworzony', 'Row: ' + CONVERT(varchar(10), @RowId) )
			END
			-- teraz mogę dodać statek
			insert into statek 
				select wlasciciel, nazwa, zasieg, atak, obrona, szybkosc
				from imported_rows where row_id = @RowId

			-- aktualizujemy informację o zaimportowenym wierszu
			update imported_rows
				set imp_status = 'imported'
			where imported_rows.row_id = @RowId

			-- ustawiamy też master, do jakiego się odnosił
			update imported_rows
				set master_id = wlasciciel
			where imported_rows.row_id = @RowId

			insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK - statek został dodany', 'Row: ' + CONVERT(varchar(10), @RowId) )
		END

		
		FETCH NEXT FROM MY_CURSOR INTO @RowId
	END
	CLOSE MY_CURSOR
	DEALLOCATE MY_CURSOR

	update imp
		set end_dt = GETDATE()
	where end_dt is null

	insert into LOG(proc_name, msg, step_name) values('Procesowanie danych z imported rows','OK', 'zakończone')

go

-- Dodaję przykładowych użytkowników (i administratorów)

insert into usr(email, is_admin) values('michal.jereczek@gmail.com', 1)
insert into usr(email, is_admin) values('shafear100@gmail.com', 1)
insert into usr(email) values('jereczem@ee.pw.edu.pl')

go

CREATE PROCEDURE mail_do_adminow(@mail_subject nvarchar(max))
AS	
		declare @admin_mails nvarchar(max)

		select @admin_mails = (SELECT email + '; '  FROM usr WHERE is_admin = 1 FOR XML PATH(''))

		insert into LOG(proc_name, msg, step_name) values('Wysłanie maila do adminów','OK', @mail_subject)

		EXEC msdb.dbo.sp_send_dbmail
		  @profile_name = 'Error mail service',
		  @recipients = @admin_mails,
		  @subject = @mail_subject,
		  @body = 
		  '<html>
		  <body>
		  <h1> W ostatnio wczytanym pakiecie wystąpiły błędy </h1>
		  <img src="https://i.warosu.org/data/fa/img/0071/11/1382390644913.jpg"></img>
		  </body>
		  </html>',
		  @body_format= 'HTML'
GO

/* oglądanie logów i zaimportowanych danych (sformatowane trochę aby ładnie zapisywać do sprawozdania
select left(msg, 35)as msg, left(proc_name, 32)as proc_name, left(step_name, 32)as step_name, row_id, entry_dt  from log 
	order by entry_dt 
select imp_id, start_dt, end_dt, err_no, left(usr_nam, 32)as usr_nam, left(host, 32)as host from imp
	order by start_dt
select imp_id, row_id, left(imp_status, 14)as imp_status, master_id, wlasciciel, left(nazwa, 16)as nazwa, zasieg, atak, obrona, szybkosc from imported_rows
	order by row_id
select left(wlasciciel + '                       ', 64)as wlasciciel, nazwa, haslo, zasieg, atak, obrona, szybkosc from statek
	join gracz on gracz.nick = statek.wlasciciel
	order by wlasciciel
*/
