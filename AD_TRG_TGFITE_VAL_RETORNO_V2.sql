--ALTER SESSION SET CURRENT_SCHEMA=HOMOLOG;

CREATE OR REPLACE TRIGGER AD_TRG_TGFITE_VAL_RETORNO_V2
BEFORE INSERT ON TGFITE
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

declare

V_ESTQTERC         TGFTOP.ATUALESTTERC%TYPE;
V_TIPMOV           TGFTOP.TIPMOV%TYPE;
V_AD_TOPVALRET     TGFTOP.AD_TOPVALRET%tYPE;
V_CODTIPOPER       TGFTOP.CODTIPOPER%TYPE;
V_ESTOQUE          TGFEST.ESTOQUE%TYPE;
V_RESERVADO        TGFEST.ESTOQUE%TYPE;
V_SALDO            TGFEST.ESTOQUE%TYPE;
V_ESTOQUELOTE      TGFEST.ESTOQUE%TYPE;
V_QUANTIDADE       TGFITE.QTDNEG%TYPE;
V_DESCRPROD        TGFPRO.DESCRPROD%TYPE;
V_TEMRASTROLOTE    TGFPRO.TEMRASTROLOTE%TYPE;
V_CODPARC          TGFCAB.CODPARC%TYPE;
V_STATUSNOTA       TGFCAB.STATUSNOTA%TYPE;
V_TOTALITEM        TGFEST.ESTOQUE%TYPE;
V_ID               INTEGER;
V_DTENTSAI         TGFCAB.DTENTSAI%TYPE;
V_NUMNOTA          TGFCAB.NUMNOTA%TYPE;

BEGIN
/************************************************************************************************************
-- Task [Logistica] PE2.48 - Validar Vencimento e Lote Inativo na rotina de transferencia entre locais
https://grupoboticario.kanbanize.com/ctrl_board/301/cards/1188425/details/

---Criado por Ana Paula Colombo em 25/02/25
-- Objetivo:  Não permitir inserir produtos sem saldo de remessa ou de lotes que não foram enviados

*************************************************************************************************************/
       V_TOTALITEM:= 0;

       SELECT CODTIPOPER, CODPARC, STATUSNOTA , DTENTSAI, NUMNOTA
       INTO   V_CODTIPOPER, V_CODPARC, V_STATUSNOTA, V_DTENTSAI, V_NUMNOTA
       FROM TGFCAB
       WHERE NUNOTA =:NEW.NUNOTA;

       -- Busca configuração  da top, se controla estoque de terceiro e se valida retorno
       SELECT DISTINCT ATUALESTTERC , TIPMOV, NVL(AD_TOPVALRET, 'N')
         INTO V_ESTQTERC, V_TIPMOV, V_AD_TOPVALRET
         FROM TGFTOP
         WHERE TGFTOP.CODTIPOPER = V_CODTIPOPER
         AND   TGFTOP.DHALTER   = (select max(dhalter) from tgftop where codtipoper = V_CODTIPOPER) ;


       IF( V_ESTQTERC in ('R', 'P') AND (V_AD_TOPVALRET = 'S')  ) then
           -- Consulta o saldo do produto sem considerar lote, se tiver saldo importa a nota.
                 SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                        INTO V_ESTOQUE , V_RESERVADO
             FROM TGFEST EST
             WHERE EST.CODEMP  =  :NEW.CODEMP
             AND   EST.CODPARC =  V_CODPARC
             AND   EST.CODPROD =  :NEW.CODPROD
             AND   EST.CODLOCAL = :NEW.CODLOCALORIG;

            -- Calcula o saldo disponivel
            IF V_ESTOQUE > v_RESERVADO THEN
               V_SALDO := V_ESTOQUE - V_RESERVADO;
            ELSE
               V_SALDO :=  V_ESTOQUE ;
            END IF;

          -- Verifica se o produto tem rastro de lote ou não para consultar o estoque do item
           -- Consulta estoque do item analisando lote
           -- E grava se tiver divergencia do saldo do lote.
           SELECT NVL(TEMRASTROLOTE, 'N') INTO V_TEMRASTROLOTE
            FROM TGFPRO
            WHERE CODPROD = :NEW.CODPROD;

            IF (V_TEMRASTROLOTE = 'S')  THEN
                 SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                        INTO V_ESTOQUE , V_RESERVADO
                  FROM TGFEST EST
                 WHERE EST.CODEMP  =  :NEW.CODEMP
                 AND   EST.CODPARC =  V_CODPARC
                 AND   EST.CODPROD =  :NEW.CODPROD
                 AND   EST.CONTROLE = :NEW.CONTROLE
                 AND   EST.CODLOCAL = :NEW.CODLOCALORIG;

             ELSE
                 SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                        INTO V_ESTOQUE , V_RESERVADO
                  FROM TGFEST EST
                 WHERE EST.CODEMP  =  :NEW.CODEMP
                 AND   EST.CODPARC =  V_CODPARC
                 AND   EST.CODPROD =  :NEW.CODPROD
                 AND   EST.CODLOCAL = :NEW.CODLOCALORIG;

            END IF;
            -- Calcula o saldo disponivel
            IF V_ESTOQUE > v_RESERVADO THEN
               V_ESTOQUELOTE := V_ESTOQUE - V_RESERVADO;
            ELSE
               V_ESTOQUELOTE :=  V_ESTOQUE ;
            END IF;

           -- Verifica se tem estoque disponivel do lote
              IF ( V_ESTOQUELOTE < :NEW.QTDNEG ) or (V_ESTOQUELOTE = 0) THEN
                  :NEW.AD_DIVERG_IMP := 'S';
                  
                 -- INSERE NA TABELA DE LOG NOTA/PEDIDO SE TIVER DIVERGENCIA 
                  IF INSERTING THEN
                        SELECT NVL(MAX(ID),0)+ 1 INTO V_ID FROM  AD_LOGNOTA;
                        -- Atualiza tabela de LOG
                        INSERT INTO AD_LOGNOTA
                        (ID, NUNOTA, NUMNOTA,  CODPROD, SEQ, LOTEORIG, LOTEALT, CODLOCALORIG, CODLOCALALT, UNIDADEORIG, UNIDADEALT,
                         QTDEORIG, QTDEALT, CODPARC, CODTIPOPER, DTENTSAI,  CODUSU, DHALTERACAO) VALUES
                        (V_ID, :NEW.NUNOTA,V_NUMNOTA, :NEW.CODPROD, :NEW.SEQUENCIA, :NEW.CONTROLE, NULL, :NEW.CODLOCALORIG, NULL,  :NEW.CODVOL, NULL,
                        :NEW.QTDNEG, NULL, V_CODPARC, V_CODTIPOPER, V_DTENTSAI,  STP_GET_CODUSULOGADO, SYSDATE);
                  END IF;                  
              ELSE
                  :NEW.AD_DIVERG_IMP := 'N';
              END IF ;


     /* vamos comentar para não validar na altualização do item

              -- Decisão Depto Fiscal em 01/04/25 - não bloquear a importação
               -- Só bloqueia se não tiver saldo em lote nenhum do produto.
            IF (V_SALDO = 0) OR (V_SALDO < :NEW.QTDNEG) THEN
                           raise_application_error(-20101,
                           fc_formatahtml(p_mensagem => 'Não há estoque disponivel do produto :' || :NEW.CODPROD || ' , no local :' || :NEW.CODLOCALORIG ||' , empresa : ' || :NEW.CODEMP ||' e parceiro : '|| V_CODPARC   ,
                                          p_motivo   => ' Estoque Atual: ' ||V_SALDO|| ' . E você está tentando movimentar  : '|| :NEW.QTDNEG ||'  ',
                                          p_solucao  => ' Consulte relatório : Estoque por Local, Lote e Parceiro'));


             END IF;
    */

        END IF;


END;
