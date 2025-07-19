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

-----------------------------------------------------
-- ZMENY OPROTI PREDCHOZIM UKOLUM
-----------------------------------------------------
-- oprava chybejicich stavu vypujceni exemplaru
-- oprava chybejicich informaci zdali je spisovatel hlavnim autorem knihy
-- pridany dalsi inserty pro rozumnejsi mnozstvi dat ve vypisech

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

-- smazani pohledu a procedur ukolu 4
DROP MATERIALIZED VIEW VSECHNY_VYPUJCKY;
DROP PROCEDURE VYPIS_VYPUJCKY_CTENAR;
DROP PROCEDURE VRACENI_VYPUJCKY;


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
INSERT INTO Zanr
    (nazev, popis)
    VALUES
    ('Fikce', 'Fiktivní příběh,');

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
    ('Jaroslav', 'Němeček', TO_DATE('20-02-1942', 'DD-MM-YYYY'), 'Československo', 'Autor čtyřlístku');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Zdeněk', 'Ležák', TO_DATE('13-03-1974', 'DD-MM-YYYY'), 'Československo', 'Šéfredaktor ABC');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Fridrich', 'Mátoha', TO_DATE('05-06-1976', 'DD-MM-YYYY'), 'Československo', 'Dramatik a spisovatel (horor)');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Matilda', 'Květáková', TO_DATE('03-07-1911'), 'Rakousko-uherská monarchie', 'Autorka proslavená časopisem Příběhy ze zěmě Tamtadam,
    vydáváným nepřetržitě od roku 1930 a to i přes autorčin vysoký věk.');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Neil', 'Gaiman', TO_DATE('10-11-1960', 'DD-MM-YYYY'), 'Spojené království', 'Anglický spisovatel a novinář, autor fantasy a hororových knih');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Terry', 'Pratchett', TO_DATE('28-04-1948', 'DD-MM-YYYY'), 'Spojené království', 'Anglický spisovatel, autor fantasy knih a novinář');
INSERT INTO TVURCE
    (jmeno, prijmeni, narozen, zeme, popis)
    VALUES
    ('Martina', 'Bobková', TO_DATE('01-03-1977', 'DD-MM-YYYY'), 'Československo', 'Česká výtvarnice a ilustrátorka, autorka knih a časopisů pro děti');
-- Tituly Knihy a Casopisy

-- RUR
INSERT INTO Titul
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (1, 'R.U.R.', 'Čeština', 1920, 'R.U.R. je divadelní hra Karla Čapka z roku 1920', 256, 1);

INSERT INTO Titul_Kniha
    (id_titulu, isbn)
    VALUES
    (1, '978-80-257-4172-6');

INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (1, 1);

INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (1, 3);

INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (1, 1, 1);


--Ctyrlistek
INSERT INTO Titul
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (2, 'Čtyřlístek', 'Čeština', 2025, 'Čtyřlístek je český komiks', 30, 2);
INSERT INTO Titul_Casopis
    (id_titulu, issn, cislo_vydani)
    VALUES
    (2, '1234-5678', 1);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (2, 6);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (3, 2, 'Autor');
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (9, 2, 'Ilustrátor');

-- ABC
INSERT INTO Titul
    (id_titulu, nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    (3, 'ABC', 'Čeština', 2025, 'ABC je český časopis', 50, 3);
INSERT INTO Titul_Casopis
    (id_titulu, issn, cislo_vydani)
    VALUES
    (3, '1234-4321', 1);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (3, 2);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (4, 3, 'Šéfredaktor');

-- HOBIT (s autoinkrementaci)
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Hobit', 'Čeština', 1937, 'Hobit je fantasy kniha J. R. R. Tolkiena', 252, 2);
INSERT INTO Titul_Kniha
    (id_titulu, isbn)
    VALUES
    (4, '978-80-257-0741-8');
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (4, 4);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (4, 5);
INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (2, 4, 1);

-- Kniha o Veselém Sluníčku
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Kniha o Veselém Sluníčku', 'Brněnština', 2000, 'Jeden z nejlepších hororových příběhů.', 365, 5);
INSERT INTO Titul_Kniha
    (id_titulu, isbn)
    VALUES
    (5, '978-80-257-0741-8');
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (5, 7);
INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (5, 5, 1);
INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (9, 5, 0);
-- Příběhy ze země Tamtadam 1
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Příběhy ze země Tamtadam', 'Čeština', 2025, 'Výtržnící opět dobyli skrýš.', 24, 5);
INSERT INTO Titul_Casopis
    (id_titulu, issn, cislo_vydani)
    VALUES
    (6, '9999-1111', 1);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (6, 4);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (6, 7);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (6, 6, 'Autorka');
-- Příběhy ze země Tamtadam 2
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Příběhy ze země Tamtadam', 'Čeština', 2025, 'Snaha krále Katastrofa VI. je opět marná.', 21, 5);
INSERT INTO Titul_Casopis
    (id_titulu, issn, cislo_vydani)
    VALUES
    (7, '9999-1112', 2);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (7, 4);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (7, 7);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (6, 7, 'Autorka');
-- Příběhy ze země Tamtadam 3
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Příběhy ze země Tamtadam', 'Čeština', 2025, 'Blýská se na horší časy.', 38, 5);
INSERT INTO Titul_Casopis
    (id_titulu, issn, cislo_vydani)
    VALUES
    (8, '9999-1113', 3);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (8, 4);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (8, 7);
INSERT INTO Clen_redakce
    (id_tvurce, id_titulu, nazev_role)
    VALUES
    (6, 8, 'Autorka');
-- Kniha Dobrá znamení
INSERT INTO Titul
    (nazev, jazyk, rok, popis, pocet_stran, id_vydavatelstvi)
    VALUES
    ('Dobrá znamení', 'Angličina', 1990, 'Parodické dílo o zjevení svatého Jana', 300, 2);
INSERT INTO Titul_Kniha
    (id_titulu, isbn)
    VALUES
    (9, '978-80-7197-729-2');
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (9, 4);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (9, 5);
INSERT INTO Titul_Zanr
    (id_titulu, id_zanru)
    VALUES
    (9, 8);
INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (7, 9, 1);
INSERT INTO Spisovatel
    (id_tvurce, id_titulu, je_hlavnim)
    VALUES
    (8, 9, 0);
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

INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (6, 'Nové', 0, TO_DATE('18-01-2025', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (7, 'Nové', 0, TO_DATE('19-02-2025', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (8, 'Nové', 0, TO_DATE('20-03-2025', 'DD-MM-YYYY'));
    
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (9, 'Nové', 0, TO_DATE('21-04-2010', 'DD-MM-YYYY'));
INSERT INTO Exemplar
    (id_titulu, popis_stavu, vypujcen, porizeno)
    VALUES
    (9, 'Počmáraná strana číslo 18', 0, TO_DATE('22-05-2011', 'DD-MM-YYYY'));

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
INSERT INTO Ctenar
    (jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
VALUES
    ('Karel', 'Tvaroh', TO_DATE('11-02-1988', 'DD-MM-YYYY'), '777888999', 'karel.podlahy@seznam.cz', 'Brno', 'Veslařská', '63700', 'Česká Republika', '8802114777', '337', TO_DATE('01-04-2023', 'DD-MM-YYYY'), TO_DATE('01-04-2024', 'DD-MM-YYYY'));
INSERT INTO Ctenar
    (jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
VALUES
    ('Božena', 'Papírová', TO_DATE('12-02-1975', 'DD-MM-YYYY'), '602123456', 'bozena.cte@seznam.cz', 'Knižní Lhota', 'Záložková', '54321', 'Česká Republika', '7502125678', '7', TO_DATE('15-05-2022', 'DD-MM-YYYY'), TO_DATE('15-05-2024', 'DD-MM-YYYY'));
INSERT INTO Ctenar 
    (jmeno, prijmeni, narozen, mobil, email, mesto, ulice, psc, zeme, rodne_cislo, cislo_popisne, registrovan, posledni_platba_prispevku)
VALUES
    ('Lukáš', 'Šplíchal', TO_DATE('01-01-1990', 'DD-MM-YYYY'), '123456789', 'lukas.splichal@seznam.cz', 'Brno', 'Božetěchova', '11000', 'Česká republika', '9001011234', '123', TO_DATE('01-01-2020', 'DD-MM-YYYY'), TO_DATE('01-01-2025', 'DD-MM-YYYY'));
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
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (5, 6, 13, TO_DATE('04-02-2025', 'DD-MM-YYYY'), TO_DATE('04-03-2025', 'DD-MM-YYYY'), NULL, 999, 0, 1);
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (6, 7, 14, TO_DATE('01-02-2024', 'DD-MM-YYYY'), TO_DATE('01-03-2024', 'DD-MM-YYYY'), NULL, 500, 0, 1);
INSERT INTO Vypujcka
    (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
    VALUES
    (6, 1, 2, TO_DATE('25-02-2024', 'DD-MM-YYYY'), TO_DATE('25-03-2024', 'DD-MM-YYYY'), NULL, 600, 0, 1);

-- nastaveni vypujceno na 1 vsem exemplarum, ktere nebyly vraceny -> vraceno == NULL
UPDATE Exemplar
SET vypujcen = 1
WHERE EXISTS (
    SELECT vypujcka.id_vypujcky
    FROM Vypujcka vypujcka
    WHERE vypujcka.id_exemplare = exemplar.id_exemplare
      AND vypujcka.vraceno IS NULL
);


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




----------------------------------------------------
-- UKOL 4
----------------------------------------------------

-- EXPLAIN PLAN na slozitem dotazu (prevzato z ukolu 3)
EXPLAIN PLAN FOR
-- Detailni vypis vsech casopisu s jejich cleny redakci, zanry, vydavatelstvim a poctem exemplaru,
-- pro praci s podtabulkami zanry a clenove mohla byt vyuzita WITH klauzule
SELECT -- select s upravenymi nazvy sloupcu
    titul.nazev AS "Název",
    titul.jazyk AS "Jazyk",
    titul.rok AS "Rok vydání",
    casopis.cislo_vydani AS "Číslo vydání",
    titul.popis "Inforamce o knize",
    titul.pocet_stran AS "Počet stran",
    clenove.clenove AS "Členové redakce",
    casopis.issn AS "ISSN",
    vyd.nazev AS "Vydavatelství",
    zanry.zanry AS "Žánry",
    COUNT(ex.id_exemplare) AS "Počet exemplářů" -- pocet exemplaru
FROM
    Titul titul
JOIN -- spojeni na specializujici tabulku Knihy
    Titul_Casopis casopis ON titul.id_titulu = casopis.id_titulu
JOIN -- propojeni s vydavatelstvim titulu
    Vydavatelstvi vyd ON titul.id_vydavatelstvi = vyd.id_vydavatelstvi
JOIN ( -- agreguje zanry pro tituly jako seznam v jednom sloupci
    SELECT
        tz.id_titulu,
        LISTAGG(zanr.nazev, ', ') WITHIN GROUP (ORDER BY zanr.nazev) AS zanry -- spojeni 
    FROM
        Titul_Zanr tz
    JOIN
        Zanr zanr ON tz.id_zanru = zanr.id_zanru
    GROUP BY
        tz.id_titulu
) zanry ON titul.id_titulu = zanry.id_titulu
JOIN -- propojeni s exemplari titulu
    Exemplar ex ON titul.id_titulu = ex.id_titulu
JOIN ( -- agreguje cleny redakci pro tituly jako seznam v jednom sloupci
    SELECT
        cr.id_titulu,
        LISTAGG(tvurce.jmeno || ' ' || tvurce.prijmeni, ', ') -- spojeni
        WITHIN GROUP (ORDER BY tvurce.jmeno || ' ' || tvurce.prijmeni) AS clenove
    FROM
        Clen_redakce cr
    JOIN
        Tvurce tvurce ON cr.id_tvurce = tvurce.id_tvurce
    GROUP BY
        cr.id_titulu
) clenove ON titul.id_titulu = clenove.id_titulu
GROUP BY -- potrebna seskupeni
    titul.nazev,
    titul.jazyk,
    titul.rok,
    titul.popis,
    titul.pocet_stran,
    casopis.issn,
    casopis.cislo_vydani,
    vyd.nazev,
    zanry.zanry,
    clenove.clenove;
-- vypis EXPLAIN PLAN posledniho dotazu
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

----------------------------------------------------
-- nastaveni prav pro clena typu
-- na vsechny tabulky v tomto skriptu
----------------------------------------------------
GRANT SELECT, INSERT, UPDATE on CLEN_REDAKCE to vut253206;
GRANT SELECT, INSERT, UPDATE on CTENAR to vut253206;
GRANT SELECT, INSERT, UPDATE on EXEMPLAR to vut253206;
GRANT SELECT, INSERT, UPDATE on REZERVACE to vut253206;
GRANT SELECT, INSERT, UPDATE on SPISOVATEL to vut253206;
GRANT SELECT, INSERT, UPDATE on TITUL to vut253206;
GRANT SELECT, INSERT, UPDATE on TITUL_CASOPIS to vut253206;
GRANT SELECT, INSERT, UPDATE on TITUL_KNIHA to vut253206;
GRANT SELECT, INSERT, UPDATE on TITUL_ZANR to vut253206;
GRANT SELECT, INSERT, UPDATE on TVURCE to vut253206;
GRANT SELECT, INSERT, UPDATE on VYDAVATELSTVI to vut253206;
GRANT SELECT, INSERT, UPDATE on VYPUJCKA to vut253206;
GRANT SELECT, INSERT, UPDATE on ZANR to vut253206;

-- materializovany pohled (vyuzit jeden ze selectu z ukolu 3)
-- Vytvari materializovany pohled pro zobrazovani vsech dosavadnich vypujcek 
CREATE MATERIALIZED VIEW VSECHNY_VYPUJCKY
BUILD IMMEDIATE
REFRESH COMPLETE
AS
-- Vypis vsech vypujcek vsech ctenaru (aktivni i historie)
SELECT -- s aliasy a seskupenimi
    -- info o ctenari, jmeno a prijmeni a adresa jsou seskupeny do svych sloupcu
    ctenar.jmeno || ' ' || ctenar.prijmeni AS "Čtenář",
    ctenar.ulice || ' ' || ctenar.cislo_popisne || ', ' || ctenar.psc || ' ' || ctenar.mesto AS "Adresa",
    -- info o titulu
    titul.nazev AS "Titul",
    titul.jazyk AS "Jazyk",
    vyd.nazev AS "Vydavatelství",
    titul.rok AS "Rok vydání",
    titul.popis AS "Informace o knize",
    -- seznam zanru, seskupeny do jednoho sloupce
    LISTAGG(zanr.nazev, ', ') WITHIN GROUP (ORDER BY zanr.nazev) AS "Žánry", -- seskupeni zanru do jednoho sloupce
    -- info o vypujce
    vypujcka.vypujceno_od AS "Vypůjčeno od",
    vypujcka.vypujceno_do AS "Vypůjčeno do",
    vypujcka.vraceno AS "Datum vrácení"
FROM Ctenar ctenar
JOIN -- vypujcka ctenare
    Vypujcka vypujcka ON ctenar.id_ctenare = vypujcka.id_ctenare
JOIN -- exemplar svazany s vypujckou
    Exemplar e ON vypujcka.id_titulu = e.id_titulu AND vypujcka.id_exemplare = e.id_exemplare
JOIN -- informace o exemplari (titul)
    Titul titul ON e.id_titulu = titul.id_titulu
JOIN -- vydavatelstvi titulu
    Vydavatelstvi vyd ON titul.id_vydavatelstvi = vyd.id_vydavatelstvi
JOIN -- propojovaci tabulka Titul_Zanr
    Titul_Zanr tz ON titul.id_titulu = tz.id_titulu
JOIN -- zanry titulu
    Zanr zanr ON tz.id_zanru = zanr.id_zanru
GROUP BY
    ctenar.jmeno,
    ctenar.prijmeni,
    ctenar.ulice,
    ctenar.cislo_popisne,
    ctenar.psc,
    ctenar.mesto,
    titul.nazev,
    titul.jazyk,
    vyd.nazev,
    titul.rok,
    titul.popis,
    vypujcka.vypujceno_od,
    vypujcka.vypujceno_do,
    vypujcka.vraceno
ORDER BY
    vypujcka.vypujceno_od;

-- priklad vyuziti materializovaneho pohledu
SELECT * FROM VSECHNY_VYPUJCKY;

-- udeleni prav druhemu clenu tymu
GRANT SELECT on VSECHNY_VYPUJCKY to vut253206;

-- priklad vyvolani dotazu u druheho clena tymu
SELECT * FROM vut247555.VSECHNY_VYPUJCKY;

-- komplexni dotaz s klauzuli WITH a operatorem CASE (zanořeným)
-- Upravena verze dotazu z ukolu 3
-- Detailni vypis vsech knih s jejich autory, zanry, vydavatelstvim a poctem exemplaru,
-- pro ziskani jednotneho seznamu zanru a spisovatelu pouzivame WITH klauzuli
-- zanorene CASE operatory jsou vyuzity pro kategorizaci dle roku a jazyka
WITH zanry AS ( -- agreguje zanry pro tituly jako seznam v jednom sloupci
    SELECT
        tz.id_titulu,
        LISTAGG(zanr.nazev, ', ') WITHIN GROUP (ORDER BY zanr.nazev) AS zanry -- spojeni do jednoho sloupce
        
    FROM Titul_Zanr tz
    JOIN Zanr zanr ON tz.id_zanru = zanr.id_zanru
    GROUP BY
        tz.id_titulu
),
spisovatele AS ( -- agreguje spisovatele pro tituly jako seznam v jednom sloupci
    SELECT
        sp.id_titulu,
        LISTAGG(tvurce.jmeno || ' ' || tvurce.prijmeni, ', ') -- spojeni do jednoho sloupce
        WITHIN GROUP (ORDER BY tvurce.jmeno || ' ' || tvurce.prijmeni) AS spisovatele
    FROM Spisovatel sp
    JOIN Tvurce tvurce ON sp.id_tvurce = tvurce.id_tvurce
    GROUP BY
        sp.id_titulu
)
SELECT -- select s upravenymi nazvy sloupcu
    titul.nazev AS "Název",
    titul.jazyk AS "Jazyk", 
    titul.rok AS "Rok vydání",
    CASE
        WHEN titul.rok >= 2024 THEN
            CASE
                WHEN titul.jazyk = 'Čeština' OR titul.jazyk = 'Brněnština' THEN 'Tuzemská novinka'
                ELSE 'Zahraniční novinka'
            END
        WHEN titul.rok >= 2000 THEN
            CASE
                WHEN titul.jazyk = 'Čeština' OR titul.jazyk = 'Brněnština' THEN 'Česká literatura posledních dvou dekád'
                ELSE 'Zahraniční literatura posledních dvou dekád'
            END
        WHEN titul.rok < 2000 AND titul.rok > 1945 THEN
            CASE
                WHEN titul.jazyk = 'Čeština' OR titul.jazyk = 'Brněnština' THEN 'Česká Klasika'
                ELSE 'Zahraniční Klasika'
            END
        WHEN titul.rok <= 1945 AND titul.rok >= 1938 THEN
            CASE
                WHEN titul.jazyk = 'Čeština' OR titul.jazyk = 'Brněnština' THEN 'Česká literatura z období 2. SV'
                ELSE 'Zahraniční literatura z období 2. SV'
            END
        WHEN titul.rok < 1938 THEN
            CASE
                WHEN titul.jazyk = 'Čeština' OR titul.jazyk = 'Brněnština' THEN 'Česká historická literatura'
                ELSE 'Zahraniční historická literatura'
            END
    END AS "Kategorie",
    titul.popis "Inforamce o knize",
    titul.pocet_stran AS "Počet stran",
    tvurce.jmeno || ' ' || tvurce.prijmeni AS "Hlavní autor",
    spisovatele.spisovatele AS "Všichni autoři",
    kniha.isbn AS "ISBN",
    vyd.nazev AS "Vydavatelství",
    zanry.zanry AS "Žánry",
    COUNT(ex.id_exemplare) AS "Počet exemplářů"
FROM Titul titul
JOIN -- spojeni na specializujici tabulku Knihy
    Titul_Kniha kniha ON titul.id_titulu = kniha.id_titulu
JOIN -- propojeni s vydavatelstvim titulu
    Vydavatelstvi vyd ON titul.id_vydavatelstvi = vyd.id_vydavatelstvi
JOIN -- vyuziti agregovaneho seznamu zanru
    zanry ON titul.id_titulu = zanry.id_titulu
JOIN -- propojeni s exemplari titulu
    Exemplar ex ON titul.id_titulu = ex.id_titulu
JOIN -- propojeni s propojovaci tabulkou spisovatel, vyber pouze hlavniho autora
    Spisovatel sp  ON titul.id_titulu = sp.id_titulu AND sp.je_hlavnim = 1
JOIN -- propojeni na tvurce
    Tvurce tvurce ON sp.id_tvurce = tvurce.id_tvurce
JOIN -- vyuziti agregovaneho seznamu spisovatelu
    spisovatele ON titul.id_titulu = spisovatele.id_titulu
GROUP BY -- potrebna seskupeni
    titul.nazev,
    titul.jazyk,
    titul.rok,
    titul.popis,
    titul.pocet_stran,
    kniha.isbn,
    vyd.nazev,
    zanry.zanry,
    tvurce.jmeno,
    tvurce.prijmeni,
    spisovatele.spisovatele;     

-- TRIGGER PRO AKTUALIZACI STAVU A VALIDACI DEADLINU VYPUJCKY
-------------------------------------------------------------------
-- Testovací inserty pro tigger kontrolující validaci výpůjčky
-------------------------------------------------------------------
INSERT INTO Vypujcka (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
VALUES (1, 1, 1, TO_DATE('01-01-2025', 'DD-MM-YYYY'), TO_DATE('01-02-2025', 'DD-MM-YYYY'), NULL, 0, 0, 0);
-------------------------------------------------------------------
INSERT INTO Vypujcka (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
VALUES (1, 1, 1, TO_DATE('01-01-2025', 'DD-MM-YYYY'), TO_DATE('01-02-2025', 'DD-MM-YYYY'), TO_DATE('01-03-2025', 'DD-MM-YYYY'), 0, 0, 1);  


-- Samotná implementace triggeru pro aktualizaci stavu a validaci deadlinu vypujcky
CREATE OR REPLACE TRIGGER TRG_PRODLOUZENI_VYPUJCKA -- Reakce triggeru
AFTER UPDATE OF vypujceno_do ON Vypujcka -- Při změně data vrácení
REFERENCING OLD AS stara_vypujcka NEW AS nova_vypujcka -- Odkaz na starou a novou hodnotu
FOR EACH ROW
BEGIN
  -- Výpůjčka již byla prodloužena -> nelze ji prodloužit znovu
  IF :stara_vypujcka.prodlouzeno = 1 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Chyba: Výpůjčka byla už jednou prodloužená!');
  END IF;

  -- Nový termín vrácení nesmí být dřívější než původní -> nelze povolit
  IF :nova_vypujcka.vypujceno_do < :stara_vypujcka.vypujceno_do THEN
    RAISE_APPLICATION_ERROR(-20001, 'Chyba: Nový termín vrácení je dřívější než původní!');
  END IF;
END;
/

-- Testování triggeru v případě nevalidního data při prodloužení výpůjčky
UPDATE Vypujcka
SET vypujceno_do = TO_DATE('25-01-2025', 'DD-MM-YYYY'), prodlouzeno = 1
WHERE id_vypujcky = 8;

-- Testování triggeru v případě duplikace prodloužení výpůčky -> lze provést jen jednou
UPDATE Vypujcka
SET vypujceno_do = TO_DATE('25-04-2025', 'DD-MM-YYYY'), prodlouzeno = 1
WHERE id_vypujcky = 9;
--------------------------------------------------------------------

-- TRIGGER PRO AUTOMATICKÉ PŘIŘAZENÍ K REZERVACI PŘI VRÁCENÍ VÝPUJČKY
--------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUTOMATICKA_REZERVACE  
AFTER UPDATE OF vraceno ON Vypujcka -- Reakce triggeru při aktualizaci výpujčky
FOR EACH ROW 
DECLARE
    pocet_existujich_rezervaci INTEGER;
BEGIN
    IF :OLD.vraceno IS NULL AND :NEW.vraceno IS NOT NULL THEN -- Kontorla zda li je výpůjčka opravdu vrácena 
        SELECT COUNT(*) INTO    pocet_existujich_rezervaci FROM Rezervace -- Vyhledání zda li existuje konkrétní rezervace na daný titul
        WHERE id_titulu = :NEW.id_titulu AND stav = 'rezervovano';

        IF pocet_existujich_rezervaci > 0 THEN
            UPDATE Rezervace -- Aktualizace rezervace a přiřazení exempláře
            SET stav = 'pripraveno',
                id_exemplare = :NEW.id_exemplare
            WHERE id_rezervace = ( 
                SELECT id_rezervace FROM ( -- Nastavení nového stavu rezervace
                    SELECT id_rezervace
                    FROM Rezervace
                    WHERE id_titulu = :NEW.id_titulu
                    AND stav = 'rezervovano'
                    ORDER BY rezervovano
                )
            WHERE ROWNUM = 1  -- ROWNUM <=> Row Number <=> Číslo řádku -> zajistí vybrání pouze jedné rezervace            
            );
        END IF;
    END IF;
END;
/

-- TESTOVACÍ INSERTY TRIGGERU PRO AUTOMATICKÉ PŘIŘAZENÍ K REZERVACI PŘI VRÁCENÍ VÝPUJČKY

-- Vložení exempláře
INSERT INTO Exemplar (id_titulu, popis_stavu, vypujcen, porizeno)
VALUES (1, 'Nové', 0, TO_DATE('01-01-2020', 'DD-MM-YYYY'));


-- Vytvoření výpůjčky
INSERT INTO Vypujcka (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno, akum_penale, splaceno, prodlouzeno)
VALUES (7, 1, 1, TO_DATE('01-01-2025', 'DD-MM-YYYY'), TO_DATE('01-02-2025', 'DD-MM-YYYY'), NULL, 0, 0, 0);

-- Ověření vytvořené výpůjčky
SELECT * 
FROM Vypujcka 
WHERE id_ctenare = 7  AND id_titulu = 1;

-- Vytvoření rezervace na stejný titul
INSERT INTO Rezervace (id_ctenare, id_titulu, rezervovano, stav)
VALUES (2, 1, TO_DATE('01-01-2025', 'DD-MM-YYYY'), 'rezervovano');

-- Ověření vytvořené rezervace
SELECT * 
FROM Rezervace 
WHERE id_ctenare = 2 AND id_titulu = 1;

-- Vrácení výpůjčky
UPDATE Vypujcka
SET vraceno = TO_DATE('02-02-2025', 'DD-MM-YYYY')
WHERE id_ctenare = 7 AND id_titulu = 1;

-- Ověření aktualizované výpůjčky
SELECT * 
FROM Vypujcka 
WHERE id_ctenare = 7 AND id_titulu = 1;

-- Ověření stavu rezervace -> pripraveno
SELECT * 
FROM Rezervace 
WHERE id_titulu = 1;

-----------------------------------------------------------------------------------

-- PROCEDURA PRO VÝPIS VŠECH VÝPŮJČEK AKTIVNÍCH ČTENÁŘE
-----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE VYPIS_VYPUJCKY_CTENAR (parametr_id_ctenare IN Ctenar.id_ctenare%TYPE) IS
    -- Vytvoření kurzoru pro výběr všech aktivních výpujček čtenáře
    CURSOR vypujcky_kurzor IS 
    SELECT * FROM Vypujcka 
    WHERE id_ctenare = parametr_id_ctenare AND vraceno IS NULL;
    -- proměnná pro aktuálně zpracovávanou výpujčku
    konkretni_vypujcka Vypujcka%ROWTYPE;
    nalezena_vypujcka NUMBER := 0; -- proměnná simulující boolean
BEGIN
    OPEN vypujcky_kurzor; -- otevření kurzoru 
    LOOP -- iterace přes všechny řádky pomocí kurzoru
        FETCH vypujcky_kurzor INTO konkretni_vypujcka; -- načtení jedné konkrétní výpujčky, podle kursoru
        EXIT WHEN vypujcky_kurzor%NOTFOUND; -- konec procházení -> nelze kurzorem najít další výpůčku
        DBMS_OUTPUT.PUT_LINE('ID výpůjčky: ' || konkretni_vypujcka.id_vypujcky || ', název titulu: ' || konkretni_vypujcka.id_titulu || ', vypůjčený exemplář: ' || konkretni_vypujcka.id_exemplare);
        nalezena_vypujcka := 1;
    END LOOP;
    CLOSE vypujcky_kurzor; -- uzavření kurzoru 
    IF nalezena_vypujcka = 0 THEN -- pokud nebyla nalezena žádná výpůjčka
        DBMS_OUTPUT.PUT_LINE('Čtenář s ID: ' || parametr_id_ctenare || ' nemá žádné aktivní výpůjčky.');
    END IF;
END;
/

-- UKÁZKA TESTOOVÁNÍ VOLÁNÍM PROCEDURY NAD DATY V DATABÁZI
-------------------------------------------------------------------------------------
BEGIN 
   VYPIS_VYPUJCKY_CTENAR(1); 
END;
/ 

BEGIN 
   VYPIS_VYPUJCKY_CTENAR(2); 
END;
/ 

BEGIN 
   VYPIS_VYPUJCKY_CTENAR(3); 
END;
/ 

BEGIN 
   VYPIS_VYPUJCKY_CTENAR(7); 
END;
/ 
----------------------------------------------------------------------------------------

-- PROCEDURA PRO VRÁCENÍ VÝPUJČKY PODLE JEJÍHO ID PŘI VOLÁNÍ PROCEDURY
----------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE VRACENI_VYPUJCKY(parametr_id_vypujcky IN Vypujcka.id_vypujcky%TYPE) IS
    vracena_vypujcka Vypujcka%ROWTYPE; -- proměnná por uložení vrácenné výpůjčky
BEGIN
    -- dotaz pro získání vracenné výpujčky
    SELECT * INTO vracena_vypujcka FROM Vypujcka WHERE id_vypujcky = parametr_id_vypujcky;

    -- výpujčka již byla vrácena -> nelze ji vrátit znovu
    IF vracena_vypujcka.vraceno IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Chyba: Výpůjčka již byla vrácena!');
    END IF;
    -- aktualizace výpůjčky na vrácenou
    UPDATE Vypujcka SET vraceno = SYSDATE WHERE id_vypujcky = parametr_id_vypujcky; 

EXCEPTION -- Zachycní vyjímek
    WHEN NO_DATA_FOUND THEN -- Neexistující výpujčka -> chyba
        RAISE_APPLICATION_ERROR(-20002, 'Chyba: Výpůjčka s daným ID neexistuje!');
    WHEN OTHERS THEN -- Reprezentace možných interních chyb při hledání a aktualizace databáze
        RAISE_APPLICATION_ERROR(-20003, 'Chyba: ' || SQLERRM);
END;
/

-- TESTOVÁNÍ PROCEDURY VRACENI_VYPUJCKY
----------------------------------------------------------------------------------------
-- Validní vrácení výpujčky
BEGIN
    VRACENI_VYPUJCKY(2);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- Výpujčka již byla vrácena
BEGIN
   VRACENI_VYPUJCKY(1);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- Výpujčka neexistuje a neexistovala nikdy
BEGIN
    VRACENI_VYPUJCKY(500);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/
-------------------------------------------------------------------------------------------

-- UKÁZKA LEHKÉ OPTIMALIZACE DOTAZU NA NEVRÁCENOU VÝPUJČKU POMOCÍ INDEXU
------------------------------------------------------------------------------------------

-- TESTOVACÍ INSERTY PRO VYTVOŘENÍ INDEXU NA NEVRÁCENOU VÝPUJČKU
INSERT INTO Vypujcka (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno)
VALUES ( 2, 1, 3, TO_DATE('04-01-2024', 'DD-MM-YYYY'), TO_DATE('04-02-2024', 'DD-MM-YYYY'), NULL);

INSERT INTO Vypujcka (id_ctenare, id_titulu, id_exemplare, vypujceno_od, vypujceno_do, vraceno)
VALUES  (2, 2, 4, TO_DATE('05-01-2024', 'DD-MM-YYYY'), TO_DATE('05-02-2024', 'DD-MM-YYYY'), NULL);
-------------------------------------------------------------------------------------------

EXPLAIN PLAN FOR
SELECT * FROM Vypujcka
WHERE vraceno IS NULL AND id_ctenare = 2;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Vytvoření indexu na sloupec id_ctenare a vraceno v tabulce Vypujcka
CREATE INDEX idx_vraceno_ctenar_novy ON Vypujcka(id_ctenare, vraceno);

-- Dotaz pro vyhledání všech nevrácených výpůjček čtenáře s ID 2
SELECT * FROM Vypujcka
WHERE vraceno IS NULL AND id_ctenare = 2;

-- Použití indexu na vyhledání -> ryhclejší , nepoužívá where na každý řádek
EXPLAIN PLAN FOR
SELECT * FROM Vypujcka
WHERE vraceno IS NULL AND id_ctenare = 2;

-- Vypis vysledku EXPLAIN PLAN
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- z vypisu je videt ze doslo ke snizeni ceny dotazu

COMMIT;
