--Tým: 253206
--Autoři:
--  253206 (x253206) Martin Zůbek
--  247555 (xkocio00) Otakar Kočí


----------------------------------------------------
-- ZMENY OPROTI ER DIAGRAMU
----------------------------
-- misto enumerace pro opotrebeni exemplare je pouzito textove pole popisu stavu
-- pridano rodne cislo ke ctenari
-- prejmenovani zeme_puvodu na zeme u tvurce
-- pridana zeme ke ctenari
-- pridana zeme do adresy vydavatelstvi

----------------------------------------------------
-- DROP STATEMENTS
----------------------------------------------------

-- smazani vsech tabulek
DROP TABLE Vydavatelstvi CASCADE CONSTRAINTS;
DROP TABLE Titul CASCADE CONSTRAINTS;
DROP TABLE Zanr CASCADE CONSTRAINTS;
DROP TABLE Titul_Zanr CASCADE CONSTRAINTS;
DROP TABLE Tvurce CASCADE CONSTRAINTS;
DROP TABLE Titul_Kniha CASCADE CONSTRAINTS;
DROP TABLE Titul_Casopis CASCADE CONSTRAINTS;
DROP TABLE Spisovatel CASCADE CONSTRAINTS;
DROP TABLE Clen_redakce CASCADE CONSTRAINTS;
DROP TABLE Ctenar CASCADE CONSTRAINTS;
DROP TABLE Exemplar CASCADE CONSTRAINTS;
DROP TABLE Vypujcka CASCADE CONSTRAINTS;
DROP TABLE Rezervace CASCADE CONSTRAINTS;

-- smazani vsech sekvenci pro triggery (autoinkrementace)
DROP SEQUENCE seq_id_vydavatelstvi;
DROP SEQUENCE seq_id_titulu;
DROP SEQUENCE seq_id_zanru;
DROP SEQUENCE seq_id_tvurce;
DROP SEQUENCE seq_id_ctenare;
DROP SEQUENCE seq_id_exemplare;
DROP SEQUENCE seq_id_vypujcky;
DROP SEQUENCE seq_id_rezervace;

----------------------------------------------------
-- CREATE STATEMENTS (TABLES)
----------------------------------------------------

-- Tabulka Vydavatelstvi reprezentujici vydavatelstvi knih a casopisu v modelu knihovny
CREATE TABLE Vydavatelstvi (
    id_vydavatelstvi INTEGER,
    nazev VARCHAR(60) NOT NULL,
    mesto VARCHAR(25) NOT NULL,
    ulice VARCHAR(40) NOT NULL,
    psc VARCHAR(10) NOT NULL,
    cislo_popisne VARCHAR(10) NOT NULL,
    zeme VARCHAR(40) NOT NULL,
    popis VARCHAR(800) DEFAULT '',
    CONSTRAINT PK_Vydavatelstvi PRIMARY KEY (id_vydavatelstvi),
    -- CHECK constraints
    CONSTRAINT check_vydavelelstvi_psc
        CHECK ( -- snazili jsme se o podporu mezinarodnich vydavatelstvi (ruzne formaty PSC)
            REGEXP_LIKE(psc, '^[0-9a-zA-Z]{2}[0-9a-zA-Z]*$')
        ),
    CONSTRAINT check_vydavatelstvi_cislo_popisne
        CHECK ( -- musi zacinat nenulovou cislici
            REGEXP_LIKE(cislo_popisne, '^[1-9][0-9]*$')
        )
);


-- Tabulka Titul reprezentujici knihy a casopisy v modelu knihovny
CREATE TABLE Titul (
    id_titulu INTEGER,
    nazev VARCHAR(60) NOT NULL,
    jazyk VARCHAR(15) NOT NULL,
    rok INTEGER NOT NULL,
    popis VARCHAR(800) DEFAULT '',
    pocet_stran SMALLINT NOT NULL,
    id_vydavatelstvi INTEGER NOT NULL, -- odkaz na vydavatelstvi titulu
    CONSTRAINT PK_Titul PRIMARY KEY (id_titulu),
    CONSTRAINT FK_Titul_Vydavatelstvi FOREIGN KEY (id_vydavatelstvi) REFERENCES Vydavatelstvi (id_vydavatelstvi),
    -- CHECK constraints
    CONSTRAINT check_titul_rok
        CHECK (
            rok >= 0
        ),
    CONSTRAINT check_titul_pocet_stran
        CHECK (
            pocet_stran > 0
        )
);

-- Tabulka Zanr reprezentujici zanry knih a casopisu v modelu knihovny
CREATE TABLE Zanr (
    id_zanru INTEGER,
    nazev VARCHAR(60) NOT NULL,
    popis VARCHAR(800) DEFAULT '',
    CONSTRAINT PK_Zanr PRIMARY KEY (id_zanru)
);

-- Propojovaci tabulka modelujici vztah M:N mezi tabulkami Titul a Zanr
-- v ER diagramu nazev MA ZANR
CREATE TABLE Titul_Zanr (
    id_titulu INTEGER, -- odkaz na titul
    id_zanru INTEGER, -- odkaz na zanr
    CONSTRAINT PK_Titul_Zanr PRIMARY KEY (id_titulu, id_zanru),
    CONSTRAINT FK_Titul_Zanr_Titul FOREIGN KEY (id_titulu) REFERENCES Titul (id_titulu),
    CONSTRAINT FK_Titul_Zanr_Zanr FOREIGN KEY (id_zanru) REFERENCES Zanr (id_zanru)
);

-- Tvurce knih a casopisu v modelu knihovny
CREATE TABLE Tvurce (
    id_tvurce INTEGER,
    jmeno VARCHAR(40) NOT NULL,
    prijmeni VARCHAR(40) NOT NULL,
    narozen DATE NOT NULL,
    zeme VARCHAR(40) NOT NULL,
    popis VARCHAR(800) DEFAULT '',
    CONSTRAINT PK_Tvurce PRIMARY KEY (id_tvurce)
);

-- Specializace jsme naimplementovali pomoci rodicovskych a speciaializacnich tabulek
-- specializacni tabulky obsahuji odkaz na rodicovskou tabulku (je i PK specializacni tabulky),
-- dale obsahuji doplnujici atributy

-- Specializace Titulu -> Kniha
CREATE TABLE Titul_Kniha (
    id_titulu INTEGER, -- odkaz na titul (rodic)
    isbn VARCHAR(18) NOT NULL,
    CONSTRAINT PK_Titul_Kniha PRIMARY KEY (id_titulu),
    CONSTRAINT FK_Titul_Kniha_Titul
        FOREIGN KEY (id_titulu)
        REFERENCES Titul (id_titulu)
        ON DELETE CASCADE,
    -- CHECK constraints
    CONSTRAINT check_kniha_isbn
        CHECK ( -- kontrola formatu ISBN (bez kontrolniho cisla)
            REGEXP_LIKE(isbn, '^[0-9]{3}-[0-9]{1,5}-[0-9]{1,7}-[0-9]{1,7}-[0-9]{1}$')
        )
);
-- Specializace Titulu -> Casopis
-- dalsi_dil a predchozi_dil jsou odkazy na dalsi a predchozi dil casopisu
-- mohou tedy byt i prazdne -> NULL
CREATE TABLE Titul_Casopis (
    id_titulu INTEGER, -- odkaz na titul (rodic)
    issn VARCHAR(10) NOT NULL,
    cislo_vydani SMALLINT NOT NULL,
    dalsi_dil INTEGER NULL,
    predchozi_dil INTEGER NULL,
    CONSTRAINT PK_Titul_Casopis PRIMARY KEY (id_titulu),
    CONSTRAINT
        FK_Titul_Casopis_Titul
        FOREIGN KEY (id_titulu)
        REFERENCES Titul (id_titulu)
        ON DELETE CASCADE,
    CONSTRAINT FK_Titul_Casopis_Dalsi_dil
        FOREIGN KEY (dalsi_dil)
        REFERENCES Titul_Casopis (id_titulu)
        ON DELETE SET NULL,
    CONSTRAINT FK_Titul_Casopis_Predchozi_dil
        FOREIGN KEY (predchozi_dil)
        REFERENCES Titul_Casopis (id_titulu)
        ON DELETE SET NULL,
    -- CHECK constraints
    CONSTRAINT check_casopis_issn
        CHECK ( -- kontrola formatu ISSN (bez kontrolniho cisla)
            REGEXP_LIKE(issn, '^[0-9]{4}-[0-9]{4}$')
        ),
    CONSTRAINT check_casopis_cislo_vydani
        CHECK (
            cislo_vydani > 0
        )
);

-- Spisovatel, vztah M:N mezi Tvurcem a Knihou (propojovaci tabulka)
-- v ER diagramu nazev JE SPISOVATELEM
CREATE TABLE Spisovatel (
    id_tvurce INTEGER, -- odkaz na tvurce
    id_titulu INTEGER, -- odkaz na titul
    je_hlavnim NUMBER(1) DEFAULT 0 NOT NULL CHECK (je_hlavnim IN (0, 1)), -- simulace booleanu
    CONSTRAINT PK_Spisovatel PRIMARY KEY (id_tvurce, id_titulu),
    CONSTRAINT FK_Spisovatel_Tvurce
        FOREIGN KEY (id_tvurce)
        REFERENCES Tvurce (id_tvurce)
        ON DELETE CASCADE,
    CONSTRAINT FK_Spisovatel_Kniha
        FOREIGN KEY (id_titulu)
        REFERENCES Titul_Kniha (id_titulu)
        ON DELETE CASCADE
);

-- Clen redakce, vztah M:N mezi Tvurcem a Casopisem (propojovaci tabulka)
-- v ER diagramu nazev JE CLENEM REDAKCE
CREATE TABLE Clen_redakce (
    id_tvurce INTEGER, -- odkaz na tvurce
    id_titulu INTEGER, -- odkaz na titul
    nazev_role VARCHAR(30) NOT NULL,
    CONSTRAINT PK_Clen_redakce PRIMARY KEY (id_tvurce, id_titulu),
    CONSTRAINT FK_Clen_redakce_Tvurce
        FOREIGN KEY (id_tvurce)
        REFERENCES Tvurce (id_tvurce)
        ON DELETE CASCADE,
    CONSTRAINT FK_Clen_redakce_Casopis
        FOREIGN KEY (id_titulu)
        REFERENCES Titul_Casopis (id_titulu)
        ON DELETE CASCADE
);

-- Ctenar v modelu knihovny
CREATE TABLE Ctenar (
    id_ctenare INTEGER,
    jmeno VARCHAR(40) NOT NULL,
    prijmeni VARCHAR(40) NOT NULL,
    narozen DATE NOT NULL,
    mobil VARCHAR(15) NOT NULL,
    email VARCHAR(256) NOT NULL,
    mesto VARCHAR(25) NOT NULL,
    ulice VARCHAR(40) NOT NULL,
    psc VARCHAR(10) NOT NULL,
    zeme VARCHAR(40) NOT NULL,
    rodne_cislo VARCHAR(10) NOT NULL,
    cislo_popisne VARCHAR(10) NOT NULL,
    registrovan DATE NOT NULL,
    posledni_platba_prispevku DATE NOT NULL,
    CONSTRAINT PK_Ctenar PRIMARY KEY (id_ctenare),
    -- CHECK constraints
    CONSTRAINT check_ctenar_mobil
        CHECK ( -- cislo bez mezer, podpora vice nez 9 cislic
            REGEXP_LIKE(mobil, '^[0-9]{9,15}$')
        ),
    CONSTRAINT check_ctenar_email
        CHECK ( -- jednoducha kontrola emailu
            REGEXP_LIKE(email, '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        ),
    CONSTRAINT check_ctenar_psc
        CHECK ( -- ctenari pouze z CR
            REGEXP_LIKE(psc, '^[0-9]{5}$')
        ),
    CONSTRAINT check_ctenar_rodne_cislo
        CHECK ( -- kontrola rodneho cisla (nekontrulujeme semantiku)
            REGEXP_LIKE(rodne_cislo, '^[0-9]{2}[0-1][0-2][0-3][0-9][0-9]{4}$')
        ),
    CONSTRAINT check_ctenar_cislo_popisne
        CHECK (
            REGEXP_LIKE(cislo_popisne, '^[1-9][0-9]*$')
        )
);

-- Exemplar knihy nebo casopisu (titulu) v modelu knihovny
CREATE TABLE Exemplar (
    id_titulu INTEGER, -- odkaz na titul
    id_exemplare INTEGER,
    popis_stavu VARCHAR(800) DEFAULT '',
    vypujcen NUMBER(1) DEFAULT 0 NOT NULL CHECK (vypujcen IN (0, 1)), -- simulace booleanu
    porizeno DATE NOT NULL,
    CONSTRAINT PK_Exemplar PRIMARY KEY (id_titulu, id_exemplare),
    CONSTRAINT FK_Exemplar_Titul
        FOREIGN KEY (id_titulu)
        REFERENCES Titul (id_titulu)
        ON DELETE CASCADE
);

-- Vypujcka exemplare knihy nebo casopisu v modelu knihovny
CREATE TABLE Vypujcka (
    id_vypujcky INTEGER,
    id_ctenare INTEGER, -- odkaz na ctenare
    id_titulu INTEGER, -- odkaz na titul
    id_exemplare INTEGER, -- odkaz na exemplar
    id_rezervace INTEGER NULL, -- vzesla z teto rezervace
    vypujceno_od DATE NOT NULL,
    vypujceno_do DATE NOT NULL,
    vraceno DATE NULL,
    akum_penale INTEGER DEFAULT 0 NOT NULL,
    splaceno NUMBER(1) DEFAULT 0 NOT NULL CHECK (splaceno IN (0, 1)), -- simulace booleanu
    prodlouzeno NUMBER(1) DEFAULT 0 NOT NULL CHECK (prodlouzeno IN (0, 1)), -- simulace booleanu
    CONSTRAINT PK_Vypujcka PRIMARY KEY (id_vypujcky),
    CONSTRAINT FK_Vypujcka_Ctenar
        FOREIGN KEY (id_ctenare)
        REFERENCES Ctenar (id_ctenare)
        ON DELETE CASCADE,
    CONSTRAINT FK_Vypujcka_Exemplar
        FOREIGN KEY (id_titulu, id_exemplare)
        REFERENCES Exemplar (id_titulu, id_exemplare)
        ON DELETE CASCADE,
    -- CHECK constraints
    CONSTRAINT check_vypujcka_vypujceno_do
        CHECK (
            vypujceno_do > vypujceno_od
        ),
    CONSTRAINT check_vypujcka_vraceno
        CHECK (
            vraceno >= vypujceno_od
        ),
    CONSTRAINT check_vypujcka_akum_penale
        CHECK (
            akum_penale >= 0
        )
);


-- Rezervace exemplare knihy nebo casopisu v modelu knihovny
CREATE TABLE Rezervace (
    id_rezervace INTEGER,
    id_ctenare INTEGER, -- odkaz na ctenare
    id_titulu INTEGER, -- odkaz na titul
    id_vypujcky INTEGER NULL, -- presla v tuto vypujcku
    id_exemplare INTEGER NULL, -- odkaz na exemplar (pokud je jiz vybran)
    rezervovano DATE NOT NULL, -- kdy bylo rezervovano
    stav VARCHAR(15) NOT NULL CHECK (stav IN ('rezervovano', 'pripraveno', 'vyzvednuto', 'vyprselo')),
    CONSTRAINT PK_Rezervace PRIMARY KEY (id_rezervace),
    CONSTRAINT FK_Rezervace_Ctenar
        FOREIGN KEY (id_ctenare)
        REFERENCES Ctenar (id_ctenare)
        ON DELETE CASCADE,
    CONSTRAINT FK_Rezervace_Titul
        FOREIGN KEY (id_titulu)
        REFERENCES Titul (id_titulu)
        ON DELETE CASCADE,
    CONSTRAINT FK_Rezervace_Exemplar
        FOREIGN KEY (id_titulu, id_exemplare)
        REFERENCES Exemplar (id_titulu, id_exemplare)
        ON DELETE CASCADE,
    CONSTRAINT FK_Rezervace_Vypujcka
        FOREIGN KEY (id_vypujcky)
        REFERENCES Vypujcka (id_vypujcky)
        ON DELETE SET NULL
);

-- doplneni odkazu na rezervaci do vypujcky (kruhova reference)
ALTER TABLE Vypujcka 
ADD CONSTRAINT FK_Vypujcka_Rezervace 
FOREIGN KEY (id_rezervace) 
REFERENCES Rezervace (id_rezervace)
ON DELETE SET NULL;


----------------------------------------------------
-- TRIGERS SEQUENCES
-- pro podporu autoinkrementace
-- vzdy definujeme sekvenci a trigger pro kazdou tabulku
----------------------------------------------------

CREATE SEQUENCE seq_id_vydavatelstvi START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER vydavatelstvi_on_insert
  BEFORE INSERT ON Vydavatelstvi
  FOR EACH ROW
BEGIN
  SELECT seq_id_vydavatelstvi.NEXTVAL
  INTO :new.id_vydavatelstvi
  FROM dual;
END;
/

CREATE SEQUENCE seq_id_titulu START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER titul_on_insert
  BEFORE INSERT ON Titul
  FOR EACH ROW
BEGIN
  SELECT seq_id_titulu.NEXTVAL
  INTO :new.id_titulu
  FROM dual;
END;
/

CREATE SEQUENCE seq_id_zanru START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER zanr_on_insert
  BEFORE INSERT ON Zanr
  FOR EACH ROW
BEGIN
    SELECT seq_id_zanru.NEXTVAL
    INTO :new.id_zanru
    FROM dual;
END;
/

CREATE SEQUENCE seq_id_tvurce START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER tvurce_on_insert
  BEFORE INSERT ON Tvurce
  FOR EACH ROW
BEGIN
    SELECT seq_id_tvurce.NEXTVAL
    INTO :new.id_tvurce
    FROM dual;
END;
/

CREATE SEQUENCE seq_id_ctenare START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER ctenar_on_insert
  BEFORE INSERT ON Ctenar
  FOR EACH ROW
BEGIN
    SELECT seq_id_ctenare.NEXTVAL
    INTO :new.id_ctenare
    FROM dual;
END;
/

CREATE SEQUENCE seq_id_exemplare START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER exemplar_on_insert
  BEFORE INSERT ON Exemplar
  FOR EACH ROW
BEGIN
    SELECT seq_id_exemplare.NEXTVAL
    INTO :new.id_exemplare
    FROM dual;
END;
/

CREATE SEQUENCE seq_id_vypujcky START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER vypujcka_on_insert
  BEFORE INSERT ON Vypujcka
  FOR EACH ROW
BEGIN
    SELECT seq_id_vypujcky.NEXTVAL
    INTO :new.id_vypujcky
    FROM dual;
END;
/

CREATE SEQUENCE seq_id_rezervace START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER rezervace_on_insert
  BEFORE INSERT ON Rezervace
  FOR EACH ROW
BEGIN
    SELECT seq_id_rezervace.NEXTVAL
    INTO :new.id_rezervace
    FROM dual;
END;
/

----------------------------------------------------
-- INSERT STATEMENTS (DATA)
----------------------------------------------------

-- Vydavatelstvi
INSERT INTO Vydavatelstvi
    (id_vydavatelstvi, nazev, mesto, ulice, psc, cislo_popisne, zeme, popis)
    VALUES
    (1, 'Albatros', 'Praha', '5 května', '14000', '1746', 'Česká Republika', 'Vydavatelstvi Albatros');

INSERT INTO Vydavatelstvi
    (id_vydavatelstvi, nazev, mesto, ulice, psc, cislo_popisne, zeme, popis)
    VALUES
    (2, 'Argo', 'Praha', 'Miličova', '13000', '67', 'Česká Republika', 'Nakldatelství Argo se specializuje na zahraniční literaturu');

-- vyuziti autoinkrementace
INSERT INTO Vydavatelstvi
    (nazev, mesto, ulice, psc, cislo_popisne, zeme, popis)
    VALUES
    ('Czech News Center', 'Praha', 'Komunardů', '17000', '1584', 'Česká Republika', 'Vydavatelstvi Czech News Center je jedním z největších mediálních domů v ČR.');

INSERT INTO Vydavatelstvi
    (nazev, mesto, ulice, psc, cislo_popisne, zeme, popis)
    VALUES
    ('Redakce čtyřlístku', 'Praha', 'Na Klikovce', '14000', '922', 'Česká Republika', 'Vydavatelstvi čtyřlístku');
INSERT INTO Vydavatelstvi
    (nazev, mesto, ulice, psc, cislo_popisne, zeme, popis)
    VALUES
    ('Knihy domácí', 'Brno', 'Kyjevská', '60200', '5', 'Česká Republika', 'Specialista na literaturu domácí.'); 

-- Zanr
INSERT INTO Zanr
    (id_zanru, nazev, popis)
    VALUES
    (1, 'Sci-fi', 'Vědeckofantastický žánr');

INSERT INTO Zanr
    (id_zanru, nazev, popis)
    VALUES
    (2, 'Vědecko-technický časopis', 'Časopis zaměřený na vědecké a technické novinky');

INSERT INTO Zanr
    (id_zanru, nazev, popis)
    VALUES
    (3, 'Drama', 'Dramatický žánr');

-- vyuziti autoinkrementace
INSERT INTO Zanr
    (nazev, popis)
    VALUES
    ('Fantasy', 'Fantastický žánr');

INSERT INTO Zanr
    (nazev, popis)
    VALUES
    ('Dobrodružný', 'Žánr plný dobrodružství a napětí');

INSERT INTO Zanr
    (nazev, popis)
    VALUES
    ('Pro děti', 'Knihy pro nejmladší čtenáře');
INSERT INTO Zanr
    (nazev, popis)
    VALUES
    ('Horor', 'Vhodné pro dospělé čtenáře');

-- Tvurce
INSERT INTO TVURCE
    (id_tvurce, jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    (1, 'Karel', 'Čapek', TO_DATE('09-01-1890', 'DD-MM-YYYY'), 'Československo', 'Český spisovatel, novinář a dramatik');

INSERT INTO TVURCE
    (id_tvurce, jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    (2, 'J. R. R.', 'Tolkien', TO_DATE('03-01-1892', 'DD-MM-YYYY'), 'Spojené království', 'Anglický spisovatel, filolog a univerzitní profesor');

-- vyuziti autoinkrementace
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Jaroslav', 'Neměček', TO_DATE('20-02-1942', 'DD-MM-YYYY'), 'Československo', 'Autor čtyřlístku');

INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Zdeněk', 'Ležák', TO_DATE('13-03-1974', 'DD-MM-YYYY'), 'Československo', 'Šéfredaktor ABC');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Fridrich', 'Mátoha', TO_DATE('05-06-1976', 'DD-MM-YYYY'), 'Československo', 'Dramatik a spisovatel (horor)');


-- Tituly Knihy a Casopisy

-- RUR
INSERT INTO TITUL
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (1, 'R.U.R.', 'Čeština', 1920, 'R.U.R. je divadelní hra Karla Čapka z roku 1920', 256, 1);

INSERT INTO TITUL_KNIHA
    (id_titulu, isbn)
    VALUES
    (1, '978-80-257-4172-6');

INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (1, 1);

INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (1, 3);

INSERT INTO SPISOVATEL
    (id_tvurce, id_titulu)
    VALUES
    (1, 1);


--Ctyrlistek
INSERT INTO TITUL
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (2, 'Čtyřlístek', 'Čeština', 2025, 'Čtyřlístek je český komiks', 30, 2);
INSERT INTO TITUL_CASOPIS
    (id_titulu, issn, cislo_vydani)
    VALUES
    (2, '1234-5678', 1);
INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (2, 6);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (3, 2, 'Autor');

-- ABC
INSERT INTO TITUL
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (3, 'ABC', 'Čeština', 2025, 'ABC je český časopis', 50, 3);
INSERT INTO TITUL_CASOPIS
    (id_titulu, issn, cislo_vydani)
    VALUES
    (3, '1234-4321', 1);
INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (3, 2);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (4, 3, 'Šéfredaktor');

-- HOBIT (s autoinkrementaci)
INSERT INTO TITUL
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Hobit', 'Čeština', 1937, 'Hobit je fantasy kniha J. R. R. Tolkiena', 252, 2);
INSERT INTO TITUL_KNIHA
    (id_titulu, isbn)
    VALUES
    (4, '978-80-257-0741-8');
INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (4, 4);
INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (4, 5);
INSERT INTO SPISOVATEL
    (id_tvurce, id_titulu)
    VALUES
    (2, 4);

-- Kniha o Veselém Sluníčku
INSERT INTO TITUL
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Kniha o Veselém Sluníčku', 'Brněnština', 2000, 'Jeden z nejlepších hororových příběhů.', 365, 5);
INSERT INTO TITUL_KNIHA
    (id_titulu, isbn)
    VALUES
    (5, '978-80-257-0741-8');
INSERT INTO TITUL_ZANR
    (id_titulu, id_zanru)
    VALUES
    (5, 7);
INSERT INTO SPISOVATEL
    (id_tvurce, id_titulu)
    VALUES
    (5, 5);


-- Exemplare s autoinkrementaci
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (1, 'Nové', 0, TO_DATE('01-01-2020', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (1, 'Lehce poškozeno, strana 50 chybí.', 0, TO_DATE('20-05-2021', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (1, 'Nové', 0, TO_DATE('30-06-2022', 'DD-MM-YYYY'));

INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (2, 'Ohnuté rohy', 0, TO_DATE('20-2-2025', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (2, 'Strana 15, vytržený Bobík', 0, TO_DATE('21-02-2025', 'DD-MM-YYYY'));

INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (3, 'Nové', 0, TO_DATE('20-01-2025', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (3, 'Nové', 0, TO_DATE('22-01-2025', 'DD-MM-YYYY'));

INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (4, 'Počmáraná strana 15', 0, TO_DATE('28-06-2018', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (4, 'Nové', 0, TO_DATE('13-04-2020', 'DD-MM-YYYY'));

INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (5, 'Nové', 0, TO_DATE('01-01-2021', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (5, 'Nové', 0, TO_DATE('20-06-2022', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (5, 'Vazba chybí, sešito nití.', 0, TO_DATE('01-01-2023', 'DD-MM-YYYY'));


-- Ctenari
INSERT INTO Ctenar
    (id_ctenare, jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
    VALUES
    (1, 'Jan', 'Novák', TO_DATE('01-01-1990', 'DD-MM-YYYY'), '123456789', 'novyjan@post.edu', 'Brno', 'Křenová', '60200', 'Česká Republika', '9001011234', '123', TO_DATE('01-01-2020', 'DD-MM-YYYY'), TO_DATE('10-05-2024', 'DD-MM-YYYY'));
INSERT INTO Ctenar
    (id_ctenare, jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
    VALUES
    (2, 'Petr', 'Dvořák', TO_DATE('01-01-1995', 'DD-MM-YYYY'), '987654321', 'dvorakpet@centrum.com', 'Praha', 'Vodičkova', '11000', 'Česká Republika', '9501011234', '123', TO_DATE('01-01-2021', 'DD-MM-YYYY'), TO_DATE('06-09-2024', 'DD-MM-YYYY'));
-- vyuziti autoinkrementace
INSERT INTO Ctenar
    (jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
    VALUES
    ('Petr', 'Hadička', TO_DATE('01-01-1985', 'DD-MM-YYYY'), '123123123', 'hadicka.petrik@google.cz', 'Brno', 'Křenová', '60200', 'Česká Republika', '8501011234', '123', TO_DATE('01-01-2022', 'DD-MM-YYYY'), TO_DATE('01-01-2025', 'DD-MM-YYYY'));
INSERT INTO Ctenar
    (jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
    VALUES
    ('Petr', 'Zloděj', TO_DATE('10-10-1920', 'DD-MM-YYYY'), '453665662', 'loupeznik@tabor.cz', 'Adamov', 'Kolonie', '67904', 'Česká Republika', '2010101452', '320', TO_DATE('18-11-1989', 'DD-MM-YYYY'), TO_DATE('09-12-2024', 'DD-MM-YYYY'));

-- Vypujcky
INSERT INTO Vypujcka
    (id_vypujcky, id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (1, 1, 1, 1, TO_DATE('01-01-2021', 'DD-MM-YYYY'), TO_DATE('01-02-2021', 'DD-MM-YYYY'), TO_DATE('01-02-2021', 'DD-MM-YYYY'), 0, 0, 0);
-- vyuziti autoinkrementace
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (2, 2, 5, TO_DATE('01-01-2025', 'DD-MM-YYYY'), TO_DATE('15-02-2025', 'DD-MM-YYYY'), NULL, 20000, 0, 1);
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (4, 5, 11, TO_DATE('15-01-2025', 'DD-MM-YYYY'), TO_DATE('15-03-2025', 'DD-MM-YYYY'), NULL, 10000, 0, 1);
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (3, 5, 12, TO_DATE('19-01-2025', 'DD-MM-YYYY'), TO_DATE('19-02-2025', 'DD-MM-YYYY'), TO_DATE('01-02-2025', 'DD-MM-YYYY'), 0, 0, 0);

-- Rezervace
INSERT INTO Rezervace
    (id_rezervace, id_ctenare, id_titulu, rezervovano, stav)
    VALUES
    (1, 1, 1, TO_DATE('01-01-2025', 'DD-MM-YYYY'), 'rezervovano');
-- vyuziti autoinkrementace
INSERT INTO Rezervace
    (id_ctenare, id_titulu, id_exemplare, rezervovano, stav)
    VALUES
    (2, 4, 8, TO_DATE('10-03-2025', 'DD-MM-YYYY'), 'pripraveno');
INSERT INTO Rezervace
    (id_ctenare, id_titulu, id_vypujcky, id_exemplare, rezervovano, stav)
    VALUES
    (3, 5, 4, 12, TO_DATE('15-01-2025', 'DD-MM-YYYY'), 'vyzvednuto');


COMMIT;
