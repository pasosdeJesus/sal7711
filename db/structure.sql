SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: es_co_utf_8; Type: COLLATION; Schema: public; Owner: -
--

CREATE COLLATION public.es_co_utf_8 (provider = libc, locale = 'es_CO.UTF-8');


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: completa_obs(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.completa_obs(obs character varying, nuevaobs character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RETURN CASE WHEN obs IS NULL THEN nuevaobs
          WHEN obs='' THEN nuevaobs
          WHEN RIGHT(obs, 1)='.' THEN obs || ' ' || nuevaobs
          ELSE obs || '. ' || nuevaobs
        END;
      END; $$;


--
-- Name: f_unaccent(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_unaccent(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
      SELECT public.unaccent('public.unaccent', $1)  
      $_$;


--
-- Name: msip_agregar_o_remplazar_familiar_inverso(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_agregar_o_remplazar_familiar_inverso() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
        num2 INTEGER;
        rinv CHAR(2);
        rexistente CHAR(2);
      BEGIN
        ASSERT(TG_OP = 'INSERT' OR TG_OP = 'UPDATE');
        RAISE NOTICE 'Insertando o actualizando en msip_persona_trelacion';
        RAISE NOTICE 'TG_OP = %', TG_OP;
        RAISE NOTICE 'NEW.id = %', NEW.id;
        RAISE NOTICE 'NEW.persona1 = %', NEW.persona1;
        RAISE NOTICE 'NEW.persona2 = %', NEW.persona2;
        RAISE NOTICE 'NEW.trelacion_id = %', NEW.trelacion_id;
        RAISE NOTICE 'NEW.observaciones = %', NEW.observaciones;

        SELECT COUNT(*) INTO num2 FROM msip_persona_trelacion
          WHERE persona1 = NEW.persona2 AND persona2=NEW.persona1;
        RAISE NOTICE 'num2 = %', num2;
        ASSERT(num2 < 2);
        SELECT inverso INTO rinv FROM msip_trelacion 
          WHERE id = NEW.trelacion_id;
        RAISE NOTICE 'rinv = %', rinv;
        ASSERT(rinv IS NOT NULL);
        CASE num2
          WHEN 0 THEN
            INSERT INTO msip_persona_trelacion 
            (persona1, persona2, trelacion_id, observaciones, created_at, updated_at)
            VALUES (NEW.persona2, NEW.persona1, rinv, 'Inverso agregado automaticamente', NOW(), NOW());
          ELSE -- num2 = 1
            SELECT trelacion_id INTO rexistente FROM msip_persona_trelacion
              WHERE persona1=NEW.persona2 AND persona2=NEW.persona1;
            RAISE NOTICE 'rexistente = %', rexistente;
            IF rinv <> rexistente THEN
              UPDATE msip_persona_trelacion 
                SET trelacion_id = rinv,
                 observaciones = 'Inverso cambiado automaticamente (era ' ||
                   rexistente || '). ' || COALESCE(observaciones, ''),
                 updated_at = NOW()
                WHERE persona1=NEW.persona2 AND persona2=NEW.persona1;
            END IF;
        END CASE;
        RETURN NULL;
      END ;
      $$;


--
-- Name: msip_edad_de_fechanac_fecharef(integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_edad_de_fechanac_fecharef(anionac integer, mesnac integer, dianac integer, anioref integer, mesref integer, diaref integer) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
            SELECT CASE 
              WHEN anionac IS NULL THEN NULL
              WHEN anioref IS NULL THEN NULL
              WHEN anioref < anionac THEN -1
              WHEN mesnac IS NOT NULL AND mesnac > 0 
                AND mesref IS NOT NULL AND mesref > 0 
                AND mesnac >= mesref THEN
                CASE 
                  WHEN mesnac > mesref OR (dianac IS NOT NULL 
                    AND dianac > 0 AND diaref IS NOT NULL 
                    AND diaref > 0 AND dianac > diaref) THEN 
                    anioref-anionac-1
                  ELSE 
                    anioref-anionac
                END
              ELSE
                anioref-anionac
            END 
          $$;


--
-- Name: msip_eliminar_familiar_inverso(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_eliminar_familiar_inverso() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
        num2 INTEGER;
      BEGIN
        ASSERT(TG_OP = 'DELETE');
        RAISE NOTICE 'Eliminando inverso de msip_persona_trelacion';
        SELECT COUNT(*) INTO num2 FROM msip_persona_trelacion
          WHERE persona1 = OLD.persona2 AND persona2=OLD.persona1;
        RAISE NOTICE 'num2 = %', num2;
        ASSERT(num2 < 2);
        IF num2 = 1 THEN
            DELETE FROM msip_persona_trelacion 
            WHERE persona1 = OLD.persona2 AND persona2 = OLD.persona1;
        END IF;
        RETURN NULL;
      END ;
      $$;


--
-- Name: msip_nombre_vereda(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_nombre_vereda() RETURNS character varying
    LANGUAGE sql
    AS $$
        SELECT 'Vereda '
      $$;


--
-- Name: msip_ubicacionpre_dpa_nomenclatura(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_ubicacionpre_dpa_nomenclatura(pais character varying, departamento character varying, municipio character varying, vereda character varying, centropoblado character varying) RETURNS text[]
    LANGUAGE sql
    AS $$
        SELECT CASE
        WHEN pais IS NULL OR pais = '' THEN
          array[NULL, NULL]
        WHEN departamento IS NULL OR departamento = '' THEN
          array[pais, NULL]
        WHEN municipio IS NULL OR municipio = '' THEN
          array[departamento || ' / ' || pais, departamento]
        WHEN (vereda IS NULL OR vereda = '') AND
        (centropoblado IS NULL OR centropoblado = '') THEN
          array[
            municipio || ' / ' || departamento || ' / ' || pais,
            municipio || ' / ' || departamento ]
        WHEN vereda IS NOT NULL THEN
          array[
            msip_nombre_vereda() || vereda || ' / ' ||
            municipio || ' / ' || departamento || ' / ' || pais,
            msip_nombre_vereda() || vereda || ' / ' ||
            municipio || ' / ' || departamento ]
        ELSE
          array[
            centropoblado || ' / ' ||
            municipio || ' / ' || departamento || ' / ' || pais,
            centropoblado || ' / ' ||
            municipio || ' / ' || departamento ]
         END
      $$;


--
-- Name: msip_ubicacionpre_id_rtablabasica(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_ubicacionpre_id_rtablabasica() RETURNS integer
    LANGUAGE sql
    AS $$
        SELECT max(id+1) FROM msip_ubicacionpre WHERE 
          (id+1) NOT IN (SELECT id FROM msip_ubicacionpre) AND 
          id<10000000
      $$;


--
-- Name: msip_ubicacionpre_nomenclatura(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msip_ubicacionpre_nomenclatura(pais character varying, departamento character varying, municipio character varying, vereda character varying, centropoblado character varying, lugar character varying, sitio character varying) RETURNS text[]
    LANGUAGE sql
    AS $$
        SELECT CASE
        WHEN (lugar IS NULL OR lugar = '') THEN
          msip_ubicacionpre_dpa_nomenclatura(pais, departamento,
          municipio, vereda, centropoblado)
        WHEN (sitio IS NULL OR sitio= '') THEN
          array[lugar || ' / ' || 
            (msip_ubicacionpre_dpa_nomenclatura(pais, departamento,
              municipio, vereda, centropoblado))[0],
          lugar || ' / ' || 
            (msip_ubicacionpre_dpa_nomenclatura(pais, departamento,
              municipio, vereda, centropoblado))[1] ]
        ELSE
          array[sitio || ' / ' || lugar || ' / ' || 
            (msip_ubicacionpre_dpa_nomenclatura(pais, departamento,
              municipio, vereda, centropoblado))[0],
          sitio || ' / ' || lugar || ' / ' || 
            (msip_ubicacionpre_dpa_nomenclatura(pais, departamento,
              municipio, vereda, centropoblado))[1] ]
        END
      $$;


--
-- Name: soundexesp(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.soundexesp(entrada text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT COST 500
    AS $$
      DECLARE
      	soundex text='';	
      	-- para determinar la primera letra
      	pri_letra text;
      	resto text;
      	sustituida text ='';
      	-- para quitar adyacentes
      	anterior text;
      	actual text;
      	corregido text;
      BEGIN
        --raise notice 'entrada=%', entrada;
        -- devolver null si recibi un string en blanco o con espacios en blanco
        IF length(trim(entrada))= 0 then
              RETURN NULL;
        END IF;


      	-- 1: LIMPIEZA:
      		-- pasar a mayuscula, eliminar la letra "H" inicial, los acentos y la enie
      		-- 'holá coñó' => 'OLA CONO'
      		entrada=translate(ltrim(trim(upper(entrada)),'H'),'ÑÁÉÍÓÚÀÈÌÒÙÜ','NAEIOUAEIOUU');

        IF array_upper(regexp_split_to_array(entrada, '[^a-zA-Z]'), 1) > 1 THEN
          RAISE NOTICE 'Esta función sólo maneja una palabra y no ''%''. Use más bien soundexespm', entrada;
      		RETURN NULL;
        END IF;

      	-- 2: PRIMERA LETRA ES IMPORTANTE, DEBO ASOCIAR LAS SIMILARES
      	--  'vaca' se convierte en 'baca'  y 'zapote' se convierte en 'sapote'
      	-- un fenomeno importante es GE y GI se vuelven JE y JI; CA se vuelve KA, etc
      	pri_letra =substr(entrada,1,1);
      	resto =substr(entrada,2);
      	CASE
      		when pri_letra IN ('V') then
      			sustituida='B';
      		when pri_letra IN ('Z','X') then
      			sustituida='S';
      		when pri_letra IN ('G') AND substr(entrada,2,1) IN ('E','I') then
      			sustituida='J';
      		when pri_letra IN('C') AND substr(entrada,2,1) NOT IN ('H','E','I') then
      			sustituida='K';
      		else
      			sustituida=pri_letra;

      	end case;
      	--corregir el parámetro con las consonantes sustituidas:
      	entrada=sustituida || resto;		
        --raise notice 'entrada tras cambios en primera letra %', entrada;

      	-- 3: corregir "letras compuestas" y volverlas una sola
      	entrada=REPLACE(entrada,'CH','V');
      	entrada=REPLACE(entrada,'QU','K');
      	entrada=REPLACE(entrada,'LL','J');
      	entrada=REPLACE(entrada,'CE','S');
      	entrada=REPLACE(entrada,'CI','S');
      	entrada=REPLACE(entrada,'YA','J');
      	entrada=REPLACE(entrada,'YE','J');
      	entrada=REPLACE(entrada,'YI','J');
      	entrada=REPLACE(entrada,'YO','J');
      	entrada=REPLACE(entrada,'YU','J');
      	entrada=REPLACE(entrada,'GE','J');
      	entrada=REPLACE(entrada,'GI','J');
      	entrada=REPLACE(entrada,'NY','N');
      	-- para debug:    --return entrada;
        --raise notice 'entrada tras cambiar letras compuestas %', entrada;

      	-- EMPIEZA EL CALCULO DEL SOUNDEX
      	-- 4: OBTENER PRIMERA letra
      	pri_letra=substr(entrada,1,1);

      	-- 5: retener el resto del string
      	resto=substr(entrada,2);

      	--6: en el resto del string, quitar vocales y vocales fonéticas
      	resto=translate(resto,'@AEIOUHWY','@');

      	--7: convertir las letras foneticamente equivalentes a numeros  (esto hace que B sea equivalente a V, C con S y Z, etc.)
      	resto=translate(resto, 'BPFVCGKSXZDTLMNRQJ', '111122222233455677');
      	-- así va quedando la cosa
      	soundex=pri_letra || resto;

      	--8: eliminar números iguales adyacentes (A11233 se vuelve A123)
      	anterior=substr(soundex,1,1);
      	corregido=anterior;

      	FOR i IN 2 .. length(soundex) LOOP
      		actual = substr(soundex, i, 1);
      		IF actual <> anterior THEN
      			corregido=corregido || actual;
      			anterior=actual;			
      		END IF;
      	END LOOP;
      	-- así va la cosa
      	soundex=corregido;

      	-- 9: siempre retornar un string de 4 posiciones
      	soundex=rpad(soundex,4,'0');
      	soundex=substr(soundex,1,4);		

      	-- YA ESTUVO
      	RETURN soundex;	
      END;	
      $$;


--
-- Name: soundexespm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.soundexespm(entrada text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT COST 500
    AS $$
      DECLARE
        soundex text = '' ;
        partes text[];
        sep text = '';
        se text = '';
      BEGIN
        entrada=translate(ltrim(trim(upper(entrada)),'H'),'ÑÁÉÍÓÚÀÈÌÒÙÜ','NAEIOUAEIOUU');
        partes=regexp_split_to_array(entrada, '[^a-zA-Z]');

        --raise notice 'partes=%', partes;
        FOR i IN 1 .. array_upper(partes, 1) LOOP
          se = soundexesp(partes[i]);
          IF length(se) > 0 THEN
            soundex = soundex || sep || se;
            sep = ' ';
            --raise notice 'i=% . soundexesp=%', i, se;
          END IF;
        END LOOP;

      	RETURN soundex;	
      END;	
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_anexo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_anexo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_anexo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_anexo (
    id integer DEFAULT nextval('public.msip_anexo_id_seq'::regclass) NOT NULL,
    descripcion character varying(1500) NOT NULL COLLATE public.es_co_utf_8,
    archivo character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    adjunto_file_name character varying(255),
    adjunto_content_type character varying(255),
    adjunto_file_size integer,
    adjunto_updated_at timestamp without time zone
);


--
-- Name: msip_bitacora; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_bitacora (
    id bigint NOT NULL,
    fecha timestamp without time zone NOT NULL,
    ip character varying(100),
    usuario_id integer,
    url character varying(1023),
    params character varying(5000),
    modelo character varying(511),
    modelo_id integer,
    operacion character varying(63),
    detalle json,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_bitacora_id_seq OWNED BY public.msip_bitacora.id;


--
-- Name: msip_centropoblado_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_centropoblado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_centropoblado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_centropoblado (
    cplocal_cod integer,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    tcentropoblado_id character varying(10) DEFAULT 'CP'::character varying NOT NULL,
    latitud double precision,
    longitud double precision,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    municipio_id integer,
    id integer DEFAULT nextval('public.msip_centropoblado_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    ultvigenciaini date,
    ultvigenciafin date,
    svgruta character varying,
    svgcdx integer,
    svgcdy integer,
    svgcdancho integer,
    svgcdalto integer,
    svgrotx double precision,
    svgroty double precision,
    CONSTRAINT msip_centropoblado_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_centropoblado_histvigencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_centropoblado_histvigencia (
    id bigint NOT NULL,
    centropoblado_id integer,
    vigenciaini date,
    vigenciafin date NOT NULL,
    nombre character varying(256),
    cplocal_cod integer,
    tcentropoblado_id character varying,
    observaciones character varying(5000)
);


--
-- Name: msip_centropoblado_histvigencia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_centropoblado_histvigencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_centropoblado_histvigencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_centropoblado_histvigencia_id_seq OWNED BY public.msip_centropoblado_histvigencia.id;


--
-- Name: msip_departamento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_departamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_departamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_departamento (
    deplocal_cod integer,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    latitud double precision,
    longitud double precision,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    pais_id integer NOT NULL,
    id integer DEFAULT nextval('public.msip_departamento_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    codiso character varying(6),
    catiso character varying(64),
    codreg integer,
    ultvigenciaini date,
    ultvigenciafin date,
    svgruta character varying,
    svgcdx integer,
    svgcdy integer,
    svgcdancho integer,
    svgcdalto integer,
    svgrotx double precision,
    svgroty double precision,
    CONSTRAINT departamento_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_departamento_histvigencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_departamento_histvigencia (
    id bigint NOT NULL,
    departamento_id integer,
    vigenciaini date,
    vigenciafin date NOT NULL,
    nombre character varying(256),
    deplocal_cod integer,
    codiso integer,
    catiso integer,
    codreg integer,
    observaciones character varying(5000)
);


--
-- Name: msip_departamento_histvigencia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_departamento_histvigencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_departamento_histvigencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_departamento_histvigencia_id_seq OWNED BY public.msip_departamento_histvigencia.id;


--
-- Name: msip_estadosol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_estadosol (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_estadosol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_estadosol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_estadosol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_estadosol_id_seq OWNED BY public.msip_estadosol.id;


--
-- Name: msip_etiqueta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_etiqueta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_etiqueta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_etiqueta (
    id integer DEFAULT nextval('public.msip_etiqueta_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT etiqueta_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_etiqueta_municipio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_etiqueta_municipio (
    etiqueta_id bigint NOT NULL,
    municipio_id bigint NOT NULL
);


--
-- Name: msip_etiqueta_persona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_etiqueta_persona (
    id bigint NOT NULL,
    etiqueta_id integer NOT NULL,
    persona_id integer NOT NULL,
    usuario_id integer NOT NULL,
    fecha date NOT NULL,
    observaciones character varying(5000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: msip_etiqueta_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_etiqueta_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_etiqueta_persona_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_etiqueta_persona_id_seq OWNED BY public.msip_etiqueta_persona.id;


--
-- Name: msip_etnia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_etnia (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    descripcion character varying(1000),
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT etnia_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_etnia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_etnia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_etnia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_etnia_id_seq OWNED BY public.msip_etnia.id;


--
-- Name: msip_fuenteprensa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_fuenteprensa (
    id integer NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    fechacreacion date,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: msip_fuenteprensa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_fuenteprensa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_fuenteprensa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_fuenteprensa_id_seq OWNED BY public.msip_fuenteprensa.id;


--
-- Name: msip_grupo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_grupo (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_grupo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_grupo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_grupo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_grupo_id_seq OWNED BY public.msip_grupo.id;


--
-- Name: msip_grupo_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_grupo_usuario (
    usuario_id integer NOT NULL,
    grupo_id integer NOT NULL
);


--
-- Name: msip_grupoper; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_grupoper (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    anotaciones character varying(1000)
);


--
-- Name: msip_grupoper_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_grupoper_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_grupoper_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_grupoper_id_seq OWNED BY public.msip_grupoper.id;


--
-- Name: msip_municipio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_municipio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_municipio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_municipio (
    munlocal_cod integer,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    latitud double precision,
    longitud double precision,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    departamento_id integer,
    id integer DEFAULT nextval('public.msip_municipio_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    codreg integer,
    ultvigenciaini date,
    ultvigenciafin date,
    tipomun character varying(32),
    svgruta character varying,
    svgcdx integer,
    svgcdy integer,
    svgcdancho integer,
    svgcdalto integer,
    svgrotx double precision,
    svgroty double precision,
    CONSTRAINT municipio_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_mundep_sinorden; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.msip_mundep_sinorden AS
 SELECT ((msip_departamento.deplocal_cod * 1000) + msip_municipio.munlocal_cod) AS idlocal,
    (((msip_municipio.nombre)::text || ' / '::text) || (msip_departamento.nombre)::text) AS nombre
   FROM (public.msip_municipio
     JOIN public.msip_departamento ON ((msip_municipio.departamento_id = msip_departamento.id)))
  WHERE ((msip_departamento.pais_id = 170) AND (msip_municipio.fechadeshabilitacion IS NULL) AND (msip_departamento.fechadeshabilitacion IS NULL))
UNION
 SELECT msip_departamento.deplocal_cod AS idlocal,
    msip_departamento.nombre
   FROM public.msip_departamento
  WHERE ((msip_departamento.pais_id = 170) AND (msip_departamento.fechadeshabilitacion IS NULL));


--
-- Name: msip_mundep; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.msip_mundep AS
 SELECT idlocal,
    nombre,
    to_tsvector('spanish'::regconfig, public.unaccent(nombre)) AS mundep
   FROM public.msip_mundep_sinorden
  ORDER BY (nombre COLLATE public.es_co_utf_8)
  WITH NO DATA;


--
-- Name: msip_municipio_histvigencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_municipio_histvigencia (
    id bigint NOT NULL,
    municipio_id integer,
    vigenciaini date,
    vigenciafin date NOT NULL,
    nombre character varying(256),
    munlocal_cod integer,
    observaciones character varying(5000),
    codreg integer
);


--
-- Name: msip_municipio_histvigencia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_municipio_histvigencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_municipio_histvigencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_municipio_histvigencia_id_seq OWNED BY public.msip_municipio_histvigencia.id;


--
-- Name: msip_oficina_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_oficina_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_oficina; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_oficina (
    id integer DEFAULT nextval('public.msip_oficina_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT oficina_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_orgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_orgsocial (
    id bigint NOT NULL,
    grupoper_id integer NOT NULL,
    telefono character varying(500),
    fax character varying(500),
    direccion character varying(500),
    pais_id integer,
    web character varying(500),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    fechadeshabilitacion date,
    tipoorg_id integer DEFAULT 2 NOT NULL
);


--
-- Name: msip_orgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_orgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_orgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_orgsocial_id_seq OWNED BY public.msip_orgsocial.id;


--
-- Name: msip_orgsocial_persona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_orgsocial_persona (
    id bigint NOT NULL,
    persona_id integer NOT NULL,
    orgsocial_id integer,
    perfilorgsocial_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    correo character varying(100),
    cargo character varying(254)
);


--
-- Name: msip_orgsocial_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_orgsocial_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_orgsocial_persona_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_orgsocial_persona_id_seq OWNED BY public.msip_orgsocial_persona.id;


--
-- Name: msip_orgsocial_sectororgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_orgsocial_sectororgsocial (
    orgsocial_id integer,
    sectororgsocial_id integer
);


--
-- Name: msip_pais_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_pais_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_pais; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_pais (
    id integer DEFAULT nextval('public.msip_pais_id_seq'::regclass) NOT NULL,
    nombre character varying(200) COLLATE public.es_co_utf_8,
    nombreiso_espanol character varying(200),
    latitud double precision,
    longitud double precision,
    alfa2 character varying(2),
    alfa3 character varying(3),
    codiso integer,
    div1 character varying(100),
    div2 character varying(100),
    div3 character varying(100),
    fechacreacion date,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    nombreiso_ingles character varying(512),
    nombreiso_frances character varying(512),
    ultvigenciaini date,
    ultvigenciafin date,
    svgruta character varying,
    svgcdx integer,
    svgcdy integer,
    svgcdancho integer,
    svgcdalto integer,
    svgrotx double precision,
    svgroty double precision
);


--
-- Name: msip_pais_histvigencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_pais_histvigencia (
    id bigint NOT NULL,
    pais_id integer,
    vigenciaini date,
    vigenciafin date NOT NULL,
    codiso integer,
    alfa2 character varying(2),
    alfa3 character varying(3),
    codcambio character varying(4)
);


--
-- Name: msip_pais_histvigencia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_pais_histvigencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_pais_histvigencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_pais_histvigencia_id_seq OWNED BY public.msip_pais_histvigencia.id;


--
-- Name: msip_perfilorgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_perfilorgsocial (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_perfilorgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_perfilorgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_perfilorgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_perfilorgsocial_id_seq OWNED BY public.msip_perfilorgsocial.id;


--
-- Name: msip_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_persona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_persona (
    id integer DEFAULT nextval('public.msip_persona_id_seq'::regclass) NOT NULL,
    nombres character varying(100) NOT NULL COLLATE public.es_co_utf_8,
    apellidos character varying(100) NOT NULL COLLATE public.es_co_utf_8,
    anionac integer,
    mesnac integer,
    dianac integer,
    sexo character(1) NOT NULL,
    numerodocumento character varying(100),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    pais_id integer,
    nacionalde integer,
    tdocumento_id integer,
    departamento_id integer,
    municipio_id integer,
    centropoblado_id integer,
    etnia_id integer DEFAULT 1 NOT NULL,
    CONSTRAINT persona_check CHECK (((dianac IS NULL) OR (((dianac >= 1) AND (((mesnac = 1) OR (mesnac = 3) OR (mesnac = 5) OR (mesnac = 7) OR (mesnac = 8) OR (mesnac = 10) OR (mesnac = 12)) AND (dianac <= 31))) OR (((mesnac = 4) OR (mesnac = 6) OR (mesnac = 9) OR (mesnac = 11)) AND (dianac <= 30)) OR ((mesnac = 2) AND (dianac <= 29))))),
    CONSTRAINT persona_mesnac_check CHECK (((mesnac IS NULL) OR ((mesnac >= 1) AND (mesnac <= 12)))),
    CONSTRAINT persona_sexo_check CHECK (((sexo = 'S'::bpchar) OR (sexo = 'F'::bpchar) OR (sexo = 'M'::bpchar)))
);


--
-- Name: msip_persona_trelacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_persona_trelacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_persona_trelacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_persona_trelacion (
    persona1 integer NOT NULL,
    persona2 integer NOT NULL,
    trelacion_id character(2) DEFAULT 'SI'::bpchar NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.msip_persona_trelacion_id_seq'::regclass) NOT NULL
);


--
-- Name: msip_sectororgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_sectororgsocial (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_sectororgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_sectororgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_sectororgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_sectororgsocial_id_seq OWNED BY public.msip_sectororgsocial.id;


--
-- Name: msip_solicitud; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_solicitud (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    fecha date NOT NULL,
    solicitud character varying(5000),
    estadosol_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_solicitud_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_solicitud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_solicitud_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_solicitud_id_seq OWNED BY public.msip_solicitud.id;


--
-- Name: msip_solicitud_usuarionotificar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_solicitud_usuarionotificar (
    usuarionotificar_id integer,
    solicitud_id integer
);


--
-- Name: msip_tcentropoblado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_tcentropoblado (
    id character varying(10) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT msip_tcentropoblado_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_tdocumento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_tdocumento (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    sigla character varying(500) NOT NULL,
    formatoregex character varying(500),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    ayuda character varying(1000)
);


--
-- Name: msip_tdocumento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_tdocumento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_tdocumento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_tdocumento_id_seq OWNED BY public.msip_tdocumento.id;


--
-- Name: msip_tema; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_tema (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    nav_ini character varying(8),
    nav_fin character varying(8),
    nav_fuente character varying(8),
    fondo_lista character varying(8),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    btn_primario_fondo_ini character varying(127),
    btn_primario_fondo_fin character varying(127),
    btn_primario_fuente character varying(127),
    btn_peligro_fondo_ini character varying(127),
    btn_peligro_fondo_fin character varying(127),
    btn_peligro_fuente character varying(127),
    btn_accion_fondo_ini character varying(127),
    btn_accion_fondo_fin character varying(127),
    btn_accion_fuente character varying(127),
    alerta_exito_fondo character varying(127),
    alerta_exito_fuente character varying(127),
    alerta_problema_fondo character varying(127),
    alerta_problema_fuente character varying(127),
    fondo character varying(127),
    color_fuente character varying(127),
    color_flota_subitem_fuente character varying,
    color_flota_subitem_fondo character varying
);


--
-- Name: msip_tema_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_tema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_tema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_tema_id_seq OWNED BY public.msip_tema.id;


--
-- Name: msip_tipoorg; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_tipoorg (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: msip_tipoorg_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_tipoorg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_tipoorg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_tipoorg_id_seq OWNED BY public.msip_tipoorg.id;


--
-- Name: msip_trelacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_trelacion (
    id character(2) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    inverso character varying(2),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT trelacion_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_trivalente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_trivalente (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: msip_trivalente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_trivalente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_trivalente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_trivalente_id_seq OWNED BY public.msip_trivalente.id;


--
-- Name: msip_tsitio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_tsitio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_tsitio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_tsitio (
    id integer DEFAULT nextval('public.msip_tsitio_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT tsitio_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: msip_ubicacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_ubicacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_ubicacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_ubicacion (
    id integer DEFAULT nextval('public.msip_ubicacion_id_seq'::regclass) NOT NULL,
    lugar character varying(500) COLLATE public.es_co_utf_8,
    sitio character varying(500) COLLATE public.es_co_utf_8,
    tsitio_id integer DEFAULT 1 NOT NULL,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    pais_id integer,
    departamento_id integer,
    municipio_id integer,
    centropoblado_id integer
);


--
-- Name: msip_ubicacionpre; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_ubicacionpre (
    id bigint NOT NULL,
    nombre character varying(2000) NOT NULL COLLATE public.es_co_utf_8,
    pais_id integer NOT NULL,
    departamento_id integer,
    municipio_id integer,
    centropoblado_id integer,
    lugar character varying(500),
    sitio character varying(500),
    tsitio_id integer,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    nombre_sin_pais character varying(500),
    vereda_id integer,
    observaciones character varying(5000),
    fechacreacion date DEFAULT now() NOT NULL,
    fechadeshabilitacion date
);


--
-- Name: msip_ubicacionpre_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_ubicacionpre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_ubicacionpre_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_ubicacionpre_id_seq OWNED BY public.msip_ubicacionpre.id;


--
-- Name: msip_vereda; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msip_vereda (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    municipio_id integer,
    verlocal_id integer,
    observaciones character varying(5000),
    latitud double precision,
    longitud double precision,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: msip_vereda_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msip_vereda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msip_vereda_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msip_vereda_id_seq OWNED BY public.msip_vereda.id;


--
-- Name: sal7711_gen_articulo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sal7711_gen_articulo (
    id integer NOT NULL,
    departamento_id integer,
    municipio_id integer,
    fuenteprensa_id integer NOT NULL,
    fecha date NOT NULL,
    pagina character varying(20) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    texto text,
    adjunto_file_name character varying,
    adjunto_content_type character varying,
    adjunto_file_size integer,
    adjunto_updated_at timestamp without time zone,
    anexo_id_antiguo integer,
    adjunto_descripcion character varying(1500)
);


--
-- Name: sal7711_gen_articulo_categoriaprensa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sal7711_gen_articulo_categoriaprensa (
    articulo_id integer NOT NULL,
    categoriaprensa_id integer NOT NULL
);


--
-- Name: sal7711_gen_articulo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sal7711_gen_articulo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sal7711_gen_articulo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sal7711_gen_articulo_id_seq OWNED BY public.sal7711_gen_articulo.id;


--
-- Name: sal7711_gen_bitacora; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sal7711_gen_bitacora (
    id integer NOT NULL,
    fecha timestamp without time zone,
    ip character varying(100),
    usuario_id integer,
    operacion character varying(50),
    detalle character varying(5000),
    detalle2 character varying(500),
    detalle3 character varying(500)
);


--
-- Name: sal7711_gen_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sal7711_gen_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sal7711_gen_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sal7711_gen_bitacora_id_seq OWNED BY public.sal7711_gen_bitacora.id;


--
-- Name: sal7711_gen_categoriaprensa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sal7711_gen_categoriaprensa (
    id integer NOT NULL,
    codigo character varying(15),
    nombre character varying(500) COLLATE public.es_co_utf_8,
    observaciones character varying(5000),
    fechacreacion date,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: sal7711_gen_categoriaprensa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sal7711_gen_categoriaprensa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sal7711_gen_categoriaprensa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sal7711_gen_categoriaprensa_id_seq OWNED BY public.sal7711_gen_categoriaprensa.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    nusuario character varying(15) NOT NULL,
    password character varying(64) DEFAULT ''::character varying NOT NULL,
    nombre character varying(50) COLLATE public.es_co_utf_8,
    descripcion character varying(50),
    rol integer DEFAULT 4,
    idioma character varying(6) DEFAULT 'es_CO'::character varying NOT NULL,
    id integer DEFAULT nextval('public.usuario_id_seq'::regclass) NOT NULL,
    fechacreacion date DEFAULT ('now'::text)::date NOT NULL,
    fechadeshabilitacion date,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
    sign_in_count integer DEFAULT 0 NOT NULL,
    failed_attempts integer,
    unlock_token character varying(64),
    locked_at timestamp without time zone,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    tema_id integer,
    CONSTRAINT usuario_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion))),
    CONSTRAINT usuario_rol_check CHECK ((rol >= 1))
);


--
-- Name: msip_bitacora id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_bitacora ALTER COLUMN id SET DEFAULT nextval('public.msip_bitacora_id_seq'::regclass);


--
-- Name: msip_centropoblado_histvigencia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado_histvigencia ALTER COLUMN id SET DEFAULT nextval('public.msip_centropoblado_histvigencia_id_seq'::regclass);


--
-- Name: msip_departamento_histvigencia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento_histvigencia ALTER COLUMN id SET DEFAULT nextval('public.msip_departamento_histvigencia_id_seq'::regclass);


--
-- Name: msip_estadosol id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_estadosol ALTER COLUMN id SET DEFAULT nextval('public.msip_estadosol_id_seq'::regclass);


--
-- Name: msip_etiqueta_persona id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_persona ALTER COLUMN id SET DEFAULT nextval('public.msip_etiqueta_persona_id_seq'::regclass);


--
-- Name: msip_etnia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etnia ALTER COLUMN id SET DEFAULT nextval('public.msip_etnia_id_seq'::regclass);


--
-- Name: msip_fuenteprensa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_fuenteprensa ALTER COLUMN id SET DEFAULT nextval('public.msip_fuenteprensa_id_seq'::regclass);


--
-- Name: msip_grupo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupo ALTER COLUMN id SET DEFAULT nextval('public.msip_grupo_id_seq'::regclass);


--
-- Name: msip_grupoper id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupoper ALTER COLUMN id SET DEFAULT nextval('public.msip_grupoper_id_seq'::regclass);


--
-- Name: msip_municipio_histvigencia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio_histvigencia ALTER COLUMN id SET DEFAULT nextval('public.msip_municipio_histvigencia_id_seq'::regclass);


--
-- Name: msip_orgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial ALTER COLUMN id SET DEFAULT nextval('public.msip_orgsocial_id_seq'::regclass);


--
-- Name: msip_orgsocial_persona id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_persona ALTER COLUMN id SET DEFAULT nextval('public.msip_orgsocial_persona_id_seq'::regclass);


--
-- Name: msip_pais_histvigencia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_pais_histvigencia ALTER COLUMN id SET DEFAULT nextval('public.msip_pais_histvigencia_id_seq'::regclass);


--
-- Name: msip_perfilorgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_perfilorgsocial ALTER COLUMN id SET DEFAULT nextval('public.msip_perfilorgsocial_id_seq'::regclass);


--
-- Name: msip_sectororgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_sectororgsocial ALTER COLUMN id SET DEFAULT nextval('public.msip_sectororgsocial_id_seq'::regclass);


--
-- Name: msip_solicitud id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud ALTER COLUMN id SET DEFAULT nextval('public.msip_solicitud_id_seq'::regclass);


--
-- Name: msip_tdocumento id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tdocumento ALTER COLUMN id SET DEFAULT nextval('public.msip_tdocumento_id_seq'::regclass);


--
-- Name: msip_tema id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tema ALTER COLUMN id SET DEFAULT nextval('public.msip_tema_id_seq'::regclass);


--
-- Name: msip_tipoorg id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tipoorg ALTER COLUMN id SET DEFAULT nextval('public.msip_tipoorg_id_seq'::regclass);


--
-- Name: msip_trivalente id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_trivalente ALTER COLUMN id SET DEFAULT nextval('public.msip_trivalente_id_seq'::regclass);


--
-- Name: msip_ubicacionpre id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre ALTER COLUMN id SET DEFAULT nextval('public.msip_ubicacionpre_id_seq'::regclass);


--
-- Name: msip_vereda id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_vereda ALTER COLUMN id SET DEFAULT nextval('public.msip_vereda_id_seq'::regclass);


--
-- Name: sal7711_gen_articulo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo ALTER COLUMN id SET DEFAULT nextval('public.sal7711_gen_articulo_id_seq'::regclass);


--
-- Name: sal7711_gen_bitacora id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_bitacora ALTER COLUMN id SET DEFAULT nextval('public.sal7711_gen_bitacora_id_seq'::regclass);


--
-- Name: sal7711_gen_categoriaprensa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_categoriaprensa ALTER COLUMN id SET DEFAULT nextval('public.sal7711_gen_categoriaprensa_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: msip_anexo msip_anexo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_anexo
    ADD CONSTRAINT msip_anexo_pkey PRIMARY KEY (id);


--
-- Name: msip_bitacora msip_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_bitacora
    ADD CONSTRAINT msip_bitacora_pkey PRIMARY KEY (id);


--
-- Name: msip_centropoblado_histvigencia msip_centropoblado_histvigencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado_histvigencia
    ADD CONSTRAINT msip_centropoblado_histvigencia_pkey PRIMARY KEY (id);


--
-- Name: msip_centropoblado msip_centropoblado_id_municipio_id_cplocal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_id_municipio_id_cplocal_key UNIQUE (municipio_id, cplocal_cod);


--
-- Name: msip_centropoblado msip_centropoblado_id_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_id_uniq UNIQUE (id);


--
-- Name: msip_centropoblado msip_centropoblado_municipio_id_id_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_municipio_id_id_unico UNIQUE (municipio_id, id);


--
-- Name: msip_centropoblado msip_centropoblado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_pkey PRIMARY KEY (id);


--
-- Name: msip_departamento_histvigencia msip_departamento_histvigencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento_histvigencia
    ADD CONSTRAINT msip_departamento_histvigencia_pkey PRIMARY KEY (id);


--
-- Name: msip_departamento msip_departamento_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT msip_departamento_id_key UNIQUE (id);


--
-- Name: msip_departamento msip_departamento_id_pais_id_deplocal_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT msip_departamento_id_pais_id_deplocal_unico UNIQUE (pais_id, deplocal_cod);


--
-- Name: msip_departamento msip_departamento_pais_id_id_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT msip_departamento_pais_id_id_unico UNIQUE (pais_id, id);


--
-- Name: msip_departamento msip_departamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT msip_departamento_pkey PRIMARY KEY (id);


--
-- Name: msip_estadosol msip_estadosol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_estadosol
    ADD CONSTRAINT msip_estadosol_pkey PRIMARY KEY (id);


--
-- Name: msip_etiqueta_persona msip_etiqueta_persona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_persona
    ADD CONSTRAINT msip_etiqueta_persona_pkey PRIMARY KEY (id);


--
-- Name: msip_etiqueta msip_etiqueta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta
    ADD CONSTRAINT msip_etiqueta_pkey PRIMARY KEY (id);


--
-- Name: msip_etnia msip_etnia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etnia
    ADD CONSTRAINT msip_etnia_pkey PRIMARY KEY (id);


--
-- Name: msip_fuenteprensa msip_fuenteprensa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_fuenteprensa
    ADD CONSTRAINT msip_fuenteprensa_pkey PRIMARY KEY (id);


--
-- Name: msip_grupo msip_grupo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupo
    ADD CONSTRAINT msip_grupo_pkey PRIMARY KEY (id);


--
-- Name: msip_grupoper msip_grupoper_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupoper
    ADD CONSTRAINT msip_grupoper_pkey PRIMARY KEY (id);


--
-- Name: msip_municipio msip_municipio_departamento_id_id_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT msip_municipio_departamento_id_id_unico UNIQUE (departamento_id, id);


--
-- Name: msip_municipio_histvigencia msip_municipio_histvigencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio_histvigencia
    ADD CONSTRAINT msip_municipio_histvigencia_pkey PRIMARY KEY (id);


--
-- Name: msip_municipio msip_municipio_id_departamento_id_munlocal_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT msip_municipio_id_departamento_id_munlocal_unico UNIQUE (departamento_id, munlocal_cod);


--
-- Name: msip_municipio msip_municipio_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT msip_municipio_id_key UNIQUE (id);


--
-- Name: msip_municipio msip_municipio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT msip_municipio_pkey PRIMARY KEY (id);


--
-- Name: msip_oficina msip_oficina_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_oficina
    ADD CONSTRAINT msip_oficina_pkey PRIMARY KEY (id);


--
-- Name: msip_orgsocial_persona msip_orgsocial_persona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_persona
    ADD CONSTRAINT msip_orgsocial_persona_pkey PRIMARY KEY (id);


--
-- Name: msip_orgsocial msip_orgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial
    ADD CONSTRAINT msip_orgsocial_pkey PRIMARY KEY (id);


--
-- Name: msip_pais msip_pais_codiso_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_pais
    ADD CONSTRAINT msip_pais_codiso_unico UNIQUE (codiso);


--
-- Name: msip_pais_histvigencia msip_pais_histvigencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_pais_histvigencia
    ADD CONSTRAINT msip_pais_histvigencia_pkey PRIMARY KEY (id);


--
-- Name: msip_pais msip_pais_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_pais
    ADD CONSTRAINT msip_pais_pkey PRIMARY KEY (id);


--
-- Name: msip_perfilorgsocial msip_perfilorgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_perfilorgsocial
    ADD CONSTRAINT msip_perfilorgsocial_pkey PRIMARY KEY (id);


--
-- Name: msip_persona msip_persona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT msip_persona_pkey PRIMARY KEY (id);


--
-- Name: msip_persona_trelacion msip_persona_trelacion_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT msip_persona_trelacion_id_key UNIQUE (id);


--
-- Name: msip_persona_trelacion msip_persona_trelacion_persona1_persona2_id_trelacion_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT msip_persona_trelacion_persona1_persona2_id_trelacion_key UNIQUE (persona1, persona2, trelacion_id);


--
-- Name: msip_persona_trelacion msip_persona_trelacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT msip_persona_trelacion_pkey PRIMARY KEY (id);


--
-- Name: msip_sectororgsocial msip_sectororgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_sectororgsocial
    ADD CONSTRAINT msip_sectororgsocial_pkey PRIMARY KEY (id);


--
-- Name: msip_solicitud msip_solicitud_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud
    ADD CONSTRAINT msip_solicitud_pkey PRIMARY KEY (id);


--
-- Name: msip_tcentropoblado msip_tcentropoblado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tcentropoblado
    ADD CONSTRAINT msip_tcentropoblado_pkey PRIMARY KEY (id);


--
-- Name: msip_tdocumento msip_tdocumento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tdocumento
    ADD CONSTRAINT msip_tdocumento_pkey PRIMARY KEY (id);


--
-- Name: msip_tema msip_tema_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tema
    ADD CONSTRAINT msip_tema_pkey PRIMARY KEY (id);


--
-- Name: msip_tipoorg msip_tipoorg_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tipoorg
    ADD CONSTRAINT msip_tipoorg_pkey PRIMARY KEY (id);


--
-- Name: msip_trelacion msip_trelacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_trelacion
    ADD CONSTRAINT msip_trelacion_pkey PRIMARY KEY (id);


--
-- Name: msip_trivalente msip_trivalente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_trivalente
    ADD CONSTRAINT msip_trivalente_pkey PRIMARY KEY (id);


--
-- Name: msip_tsitio msip_tsitio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_tsitio
    ADD CONSTRAINT msip_tsitio_pkey PRIMARY KEY (id);


--
-- Name: msip_ubicacion msip_ubicacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT msip_ubicacion_pkey PRIMARY KEY (id);


--
-- Name: msip_ubicacionpre msip_ubicacionpre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT msip_ubicacionpre_pkey PRIMARY KEY (id);


--
-- Name: msip_vereda msip_vereda_municipio_id_id_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_vereda
    ADD CONSTRAINT msip_vereda_municipio_id_id_unico UNIQUE (municipio_id, id);


--
-- Name: msip_vereda msip_vereda_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_vereda
    ADD CONSTRAINT msip_vereda_pkey PRIMARY KEY (id);


--
-- Name: sal7711_gen_articulo sal7711_gen_articulo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo
    ADD CONSTRAINT sal7711_gen_articulo_pkey PRIMARY KEY (id);


--
-- Name: sal7711_gen_bitacora sal7711_gen_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_bitacora
    ADD CONSTRAINT sal7711_gen_bitacora_pkey PRIMARY KEY (id);


--
-- Name: sal7711_gen_categoriaprensa sal7711_gen_categoriaprensa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_categoriaprensa
    ADD CONSTRAINT sal7711_gen_categoriaprensa_pkey PRIMARY KEY (id);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: index_msip_orgsocial_on_grupoper_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_orgsocial_on_grupoper_id ON public.msip_orgsocial USING btree (grupoper_id);


--
-- Name: index_msip_orgsocial_on_pais_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_orgsocial_on_pais_id ON public.msip_orgsocial USING btree (pais_id);


--
-- Name: index_msip_persona_on_etnia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_persona_on_etnia_id ON public.msip_persona USING btree (etnia_id);


--
-- Name: index_msip_solicitud_usuarionotificar_on_solicitud_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_solicitud_usuarionotificar_on_solicitud_id ON public.msip_solicitud_usuarionotificar USING btree (solicitud_id);


--
-- Name: index_msip_solicitud_usuarionotificar_on_usuarionotificar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_solicitud_usuarionotificar_on_usuarionotificar_id ON public.msip_solicitud_usuarionotificar USING btree (usuarionotificar_id);


--
-- Name: index_msip_ubicacion_on_centropoblado_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_ubicacion_on_centropoblado_id ON public.msip_ubicacion USING btree (centropoblado_id);


--
-- Name: index_msip_ubicacion_on_departamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_ubicacion_on_departamento_id ON public.msip_ubicacion USING btree (departamento_id);


--
-- Name: index_msip_ubicacion_on_municipio_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_ubicacion_on_municipio_id ON public.msip_ubicacion USING btree (municipio_id);


--
-- Name: index_msip_ubicacion_on_pais_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_ubicacion_on_pais_id ON public.msip_ubicacion USING btree (pais_id);


--
-- Name: index_msip_ubicacionpre_on_vereda_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_msip_ubicacionpre_on_vereda_id ON public.msip_ubicacionpre USING btree (vereda_id);


--
-- Name: index_usuario_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usuario_on_email ON public.usuario USING btree (email);


--
-- Name: msip_busca_mundep; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_busca_mundep ON public.msip_mundep USING gin (mundep);


--
-- Name: msip_nombre_ubicacionpre_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_nombre_ubicacionpre_b ON public.msip_ubicacionpre USING gin (to_tsvector('spanish'::regconfig, public.f_unaccent((nombre)::text)));


--
-- Name: msip_persona_anionac_ind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_persona_anionac_ind ON public.msip_persona USING btree (anionac);


--
-- Name: msip_persona_sexo_ind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_persona_sexo_ind ON public.msip_persona USING btree (sexo);


--
-- Name: msip_ubicacionpre_centropoblado_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_centropoblado_id_idx ON public.msip_ubicacionpre USING btree (centropoblado_id);


--
-- Name: msip_ubicacionpre_departamento_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_departamento_id_idx ON public.msip_ubicacionpre USING btree (departamento_id);


--
-- Name: msip_ubicacionpre_departamento_id_municipio_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_departamento_id_municipio_id_idx ON public.msip_ubicacionpre USING btree (departamento_id, municipio_id);


--
-- Name: msip_ubicacionpre_municipio_id_centropoblado_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_municipio_id_centropoblado_id_idx ON public.msip_ubicacionpre USING btree (municipio_id, centropoblado_id);


--
-- Name: msip_ubicacionpre_municipio_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_municipio_id_idx ON public.msip_ubicacionpre USING btree (municipio_id);


--
-- Name: msip_ubicacionpre_municipio_id_vereda_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_municipio_id_vereda_id_idx ON public.msip_ubicacionpre USING btree (municipio_id, vereda_id);


--
-- Name: msip_ubicacionpre_pais_id_departamento_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_pais_id_departamento_id_idx ON public.msip_ubicacionpre USING btree (pais_id, departamento_id);


--
-- Name: msip_ubicacionpre_pais_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_pais_id_idx ON public.msip_ubicacionpre USING btree (pais_id);


--
-- Name: msip_ubicacionpre_tsitio_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_tsitio_id_idx ON public.msip_ubicacionpre USING btree (vereda_id);


--
-- Name: msip_ubicacionpre_vereda_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msip_ubicacionpre_vereda_id_idx ON public.msip_ubicacionpre USING btree (vereda_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- Name: msip_persona_trelacion msip_eliminar_familiar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER msip_eliminar_familiar AFTER DELETE ON public.msip_persona_trelacion FOR EACH ROW EXECUTE FUNCTION public.msip_eliminar_familiar_inverso();


--
-- Name: msip_persona_trelacion msip_insertar_familiar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER msip_insertar_familiar AFTER INSERT OR UPDATE ON public.msip_persona_trelacion FOR EACH ROW EXECUTE FUNCTION public.msip_agregar_o_remplazar_familiar_inverso();


--
-- Name: msip_departamento departamento_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT departamento_id_pais_fkey FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_etiqueta_persona fk_rails_05a9a878fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_persona
    ADD CONSTRAINT fk_rails_05a9a878fd FOREIGN KEY (etiqueta_id) REFERENCES public.msip_etiqueta(id);


--
-- Name: msip_municipio fk_rails_089870a38d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT fk_rails_089870a38d FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_etiqueta_municipio fk_rails_10d88626c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_municipio
    ADD CONSTRAINT fk_rails_10d88626c3 FOREIGN KEY (etiqueta_id) REFERENCES public.msip_etiqueta(id);


--
-- Name: msip_etiqueta_persona fk_rails_1856abc5d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_persona
    ADD CONSTRAINT fk_rails_1856abc5d3 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: msip_bitacora fk_rails_2db961766c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_bitacora
    ADD CONSTRAINT fk_rails_2db961766c FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: msip_ubicacionpre fk_rails_2e86701dfb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_2e86701dfb FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_ubicacionpre fk_rails_3b59c12090; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_3b59c12090 FOREIGN KEY (centropoblado_id) REFERENCES public.msip_centropoblado(id);


--
-- Name: msip_orgsocial_persona fk_rails_4672f6cbcd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_persona
    ADD CONSTRAINT fk_rails_4672f6cbcd FOREIGN KEY (persona_id) REFERENCES public.msip_persona(id);


--
-- Name: msip_ubicacion fk_rails_4dd7a7f238; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT fk_rails_4dd7a7f238 FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: sal7711_gen_bitacora fk_rails_52d9d2f700; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_bitacora
    ADD CONSTRAINT fk_rails_52d9d2f700 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: msip_ubicacionpre fk_rails_558c98f353; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_558c98f353 FOREIGN KEY (vereda_id) REFERENCES public.msip_vereda(id);


--
-- Name: msip_etiqueta_municipio fk_rails_5672729520; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_municipio
    ADD CONSTRAINT fk_rails_5672729520 FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_orgsocial fk_rails_5b21e3a2af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial
    ADD CONSTRAINT fk_rails_5b21e3a2af FOREIGN KEY (grupoper_id) REFERENCES public.msip_grupoper(id);


--
-- Name: msip_solicitud_usuarionotificar fk_rails_6296c40917; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud_usuarionotificar
    ADD CONSTRAINT fk_rails_6296c40917 FOREIGN KEY (solicitud_id) REFERENCES public.msip_solicitud(id);


--
-- Name: sal7711_gen_articulo fk_rails_65eae7449f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo
    ADD CONSTRAINT fk_rails_65eae7449f FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_ubicacion fk_rails_6ed05ed576; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT fk_rails_6ed05ed576 FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_grupo_usuario fk_rails_734ee21e62; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupo_usuario
    ADD CONSTRAINT fk_rails_734ee21e62 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: msip_orgsocial fk_rails_7bc2a60574; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial
    ADD CONSTRAINT fk_rails_7bc2a60574 FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_orgsocial_persona fk_rails_7c335482f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_persona
    ADD CONSTRAINT fk_rails_7c335482f6 FOREIGN KEY (orgsocial_id) REFERENCES public.msip_orgsocial(id);


--
-- Name: sal7711_gen_articulo_categoriaprensa fk_rails_7d1213c35b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo_categoriaprensa
    ADD CONSTRAINT fk_rails_7d1213c35b FOREIGN KEY (articulo_id) REFERENCES public.sal7711_gen_articulo(id);


--
-- Name: msip_grupo_usuario fk_rails_8d24f7c1c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_grupo_usuario
    ADD CONSTRAINT fk_rails_8d24f7c1c0 FOREIGN KEY (grupo_id) REFERENCES public.msip_grupo(id);


--
-- Name: sal7711_gen_articulo fk_rails_8e3e0703f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo
    ADD CONSTRAINT fk_rails_8e3e0703f9 FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_departamento fk_rails_92093de1a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_departamento
    ADD CONSTRAINT fk_rails_92093de1a1 FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_orgsocial_sectororgsocial fk_rails_9f61a364e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_sectororgsocial
    ADD CONSTRAINT fk_rails_9f61a364e0 FOREIGN KEY (sectororgsocial_id) REFERENCES public.msip_sectororgsocial(id);


--
-- Name: msip_ubicacion fk_rails_a1d509c79a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT fk_rails_a1d509c79a FOREIGN KEY (centropoblado_id) REFERENCES public.msip_centropoblado(id);


--
-- Name: msip_solicitud fk_rails_a670d661ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud
    ADD CONSTRAINT fk_rails_a670d661ef FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: msip_ubicacion fk_rails_b82283d945; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT fk_rails_b82283d945 FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_etiqueta_persona fk_rails_beb3a49837; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_etiqueta_persona
    ADD CONSTRAINT fk_rails_beb3a49837 FOREIGN KEY (persona_id) REFERENCES public.msip_persona(id);


--
-- Name: msip_ubicacionpre fk_rails_c08a606417; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_c08a606417 FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_ubicacionpre fk_rails_c8024a90df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_c8024a90df FOREIGN KEY (tsitio_id) REFERENCES public.msip_tsitio(id);


--
-- Name: usuario fk_rails_cc636858ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_rails_cc636858ad FOREIGN KEY (tema_id) REFERENCES public.msip_tema(id);


--
-- Name: sal7711_gen_articulo fk_rails_d3b628101f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo
    ADD CONSTRAINT fk_rails_d3b628101f FOREIGN KEY (fuenteprensa_id) REFERENCES public.msip_fuenteprensa(id);


--
-- Name: msip_persona fk_rails_d5b92f1c45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT fk_rails_d5b92f1c45 FOREIGN KEY (etnia_id) REFERENCES public.msip_etnia(id);


--
-- Name: msip_solicitud_usuarionotificar fk_rails_db0f7c1dd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud_usuarionotificar
    ADD CONSTRAINT fk_rails_db0f7c1dd6 FOREIGN KEY (usuarionotificar_id) REFERENCES public.usuario(id);


--
-- Name: msip_ubicacionpre fk_rails_eba8cc9124; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_rails_eba8cc9124 FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_orgsocial_sectororgsocial fk_rails_f032bb21a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_orgsocial_sectororgsocial
    ADD CONSTRAINT fk_rails_f032bb21a6 FOREIGN KEY (orgsocial_id) REFERENCES public.msip_orgsocial(id);


--
-- Name: msip_centropoblado fk_rails_fb09f016e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT fk_rails_fb09f016e4 FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: sal7711_gen_articulo_categoriaprensa fk_rails_fcf649bab3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sal7711_gen_articulo_categoriaprensa
    ADD CONSTRAINT fk_rails_fcf649bab3 FOREIGN KEY (categoriaprensa_id) REFERENCES public.sal7711_gen_categoriaprensa(id);


--
-- Name: msip_solicitud fk_rails_ffa31a0de6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_solicitud
    ADD CONSTRAINT fk_rails_ffa31a0de6 FOREIGN KEY (estadosol_id) REFERENCES public.msip_estadosol(id);


--
-- Name: msip_ubicacionpre fk_ubicacionpre_departamento_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_ubicacionpre_departamento_municipio FOREIGN KEY (departamento_id, municipio_id) REFERENCES public.msip_municipio(departamento_id, id);


--
-- Name: msip_ubicacionpre fk_ubicacionpre_municipio_centropoblado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_ubicacionpre_municipio_centropoblado FOREIGN KEY (municipio_id, centropoblado_id) REFERENCES public.msip_centropoblado(municipio_id, id);


--
-- Name: msip_ubicacionpre fk_ubicacionpre_municipio_vereda; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_ubicacionpre_municipio_vereda FOREIGN KEY (municipio_id, vereda_id) REFERENCES public.msip_vereda(municipio_id, id);


--
-- Name: msip_ubicacionpre fk_ubicacionpre_pais_departamento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacionpre
    ADD CONSTRAINT fk_ubicacionpre_pais_departamento FOREIGN KEY (pais_id, departamento_id) REFERENCES public.msip_departamento(pais_id, id);


--
-- Name: msip_centropoblado msip_centropoblado_id_tcentropoblado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_id_tcentropoblado_fkey FOREIGN KEY (tcentropoblado_id) REFERENCES public.msip_tcentropoblado(id);


--
-- Name: msip_centropoblado msip_centropoblado_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_centropoblado
    ADD CONSTRAINT msip_centropoblado_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_municipio msip_municipio_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_municipio
    ADD CONSTRAINT msip_municipio_id_departamento_fkey FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_persona msip_persona_centropoblado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT msip_persona_centropoblado_id_fkey FOREIGN KEY (centropoblado_id) REFERENCES public.msip_centropoblado(id);


--
-- Name: msip_persona msip_persona_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT msip_persona_id_departamento_fkey FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_persona msip_persona_id_municipio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT msip_persona_id_municipio_fkey FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_ubicacion msip_ubicacion_centropoblado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT msip_ubicacion_centropoblado_id_fkey FOREIGN KEY (centropoblado_id) REFERENCES public.msip_centropoblado(id);


--
-- Name: msip_ubicacion msip_ubicacion_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT msip_ubicacion_id_departamento_fkey FOREIGN KEY (departamento_id) REFERENCES public.msip_departamento(id);


--
-- Name: msip_ubicacion msip_ubicacion_id_municipio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT msip_ubicacion_id_municipio_fkey FOREIGN KEY (municipio_id) REFERENCES public.msip_municipio(id);


--
-- Name: msip_persona persona_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT persona_id_pais_fkey FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_persona persona_nacionalde_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT persona_nacionalde_fkey FOREIGN KEY (nacionalde) REFERENCES public.msip_pais(id);


--
-- Name: msip_persona persona_tdocumento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona
    ADD CONSTRAINT persona_tdocumento_id_fkey FOREIGN KEY (tdocumento_id) REFERENCES public.msip_tdocumento(id);


--
-- Name: msip_persona_trelacion persona_trelacion_id_trelacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT persona_trelacion_id_trelacion_fkey FOREIGN KEY (trelacion_id) REFERENCES public.msip_trelacion(id);


--
-- Name: msip_persona_trelacion persona_trelacion_persona1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT persona_trelacion_persona1_fkey FOREIGN KEY (persona1) REFERENCES public.msip_persona(id);


--
-- Name: msip_persona_trelacion persona_trelacion_persona2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_persona_trelacion
    ADD CONSTRAINT persona_trelacion_persona2_fkey FOREIGN KEY (persona2) REFERENCES public.msip_persona(id);


--
-- Name: msip_ubicacion ubicacion_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT ubicacion_id_pais_fkey FOREIGN KEY (pais_id) REFERENCES public.msip_pais(id);


--
-- Name: msip_ubicacion ubicacion_id_tsitio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msip_ubicacion
    ADD CONSTRAINT ubicacion_id_tsitio_fkey FOREIGN KEY (tsitio_id) REFERENCES public.msip_tsitio(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20240221002426'),
('20240220164637'),
('20240220111410'),
('20240219221519'),
('20240219220944'),
('20231208162022'),
('20231205205600'),
('20231205205549'),
('20231205202418'),
('20231125230000'),
('20231125152810'),
('20231125152802'),
('20231124200056'),
('20231121203443'),
('20231120094041'),
('20231007095930'),
('20230927001422'),
('20230723011110'),
('20230722180204'),
('20230712163859'),
('20230622205530'),
('20230616203948'),
('20230613111532'),
('20230504084246'),
('20230404025025'),
('20230301212546'),
('20230301145222'),
('20221212021533'),
('20221211141209'),
('20221211141208'),
('20221211141207'),
('20221210155527'),
('20221208173349'),
('20221201154025'),
('20221201143440'),
('20221118032223'),
('20221102145906'),
('20221102144613'),
('20221025025402'),
('20221024222000'),
('20221024221557'),
('20220822132754'),
('20220822132000'),
('20220808141102'),
('20220805181901'),
('20220722192214'),
('20220722000850'),
('20220721200858'),
('20220721170452'),
('20220719111148'),
('20220714191555'),
('20220714191510'),
('20220714191505'),
('20220714191500'),
('20220713200444'),
('20220713200101'),
('20220613224844'),
('20220428145059'),
('20220422190546'),
('20220420154535'),
('20220420143020'),
('20220417221010'),
('20220417220914'),
('20220417203841'),
('20220413123127'),
('20220215095957'),
('20220214232150'),
('20220214121713'),
('20220213031520'),
('20211216125250'),
('20211117200456'),
('20211024105450'),
('20211010164634'),
('20210728214424'),
('20210616003251'),
('20210614120835'),
('20210414201956'),
('20210401210102'),
('20210401194637'),
('20201124145625'),
('20201124142002'),
('20201124050637'),
('20201124035715'),
('20201119125643'),
('20200919003430'),
('20200916022934'),
('20200907174303'),
('20200907165157'),
('20200723133542'),
('20200722210144'),
('20200319183515'),
('20200228235200'),
('20191219011910'),
('20191205204511'),
('20191205202150'),
('20191205200007'),
('20190926104116'),
('20190818013251'),
('20190715182611'),
('20190715083916'),
('20190625112649'),
('20190618135559'),
('20190612111043'),
('20190401175521'),
('20190331111015'),
('20190110191802'),
('20190109125417'),
('20181011104537'),
('20180921120954'),
('20180810221619'),
('20180724202353'),
('20180724135332'),
('20180720171842'),
('20180720140443'),
('20180717135811'),
('20180320230847'),
('20170414035328'),
('20170413185012'),
('20170405104322'),
('20161212175928'),
('20161108102349'),
('20160921112808'),
('20160519195544'),
('20160518025044'),
('20151030154458'),
('20151020203421'),
('20150809032138'),
('20150803082520'),
('20150724003736'),
('20150717101243'),
('20150710114451'),
('20150707164448'),
('20150702224217'),
('20150604155923'),
('20150604102321'),
('20150604101858'),
('20150603181900'),
('20150528100944'),
('20150521181918'),
('20150510130031'),
('20150510125926'),
('20150503120915'),
('20150503110048'),
('20150416074423'),
('20150413160159'),
('20150413160158'),
('20150413160157'),
('20150413160156');

