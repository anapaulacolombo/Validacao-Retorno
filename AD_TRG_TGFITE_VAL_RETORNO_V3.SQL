--ALTER SESSION SET CURRENT_SCHEMA=HOMOLOG;


CREATE OR REPLACE TRIGGER AD_TRG_TGFITE_VAL_RETORNO_V3
BEFORE UPDATE ON TGFITE
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
V_QUANTIDADE       TGFITE.QTDNEG%TYPE;
V_DESCRPROD        TGFPRO.DESCRPROD%TYPE;
V_TEMRASTROLOTE    TGFPRO.TEMRASTROLOTE%TYPE;
V_CODPARC          TGFCAB.CODPARC%TYPE;
V_STATUSNOTA       TGFCAB.STATUSNOTA%TYPE;

BEGIN
/************************************************************************************************************
-- Task [Logistica] PE2.48 - Validar Vencimento e Lote Inativo na rotina de transferencia entre locais
https://grupoboticario.kanbanize.com/ctrl_board/301/cards/1188425/details/

---Criado por Ana Paula Colombo em 25/02/25
-- Objetivo:  Não permitir retornar produtos sem saldo de remessa ou de lotes que não foram enviados
-- Nesta trigger não permite alterar a quantidade em notas de retorno
*************************************************************************************************************/

       SELECT CODTIPOPER, CODPARC, STATUSNOTA
       INTO   V_CODTIPOPER, V_CODPARC, V_STATUSNOTA
       FROM TGFCAB
       WHERE NUNOTA =:NEW.NUNOTA;

       -- Busca configuração  da top, se controla estoque de terceiro e se valida retorno
       SELECT DISTINCT ATUALESTTERC , TIPMOV, NVL(AD_TOPVALRET, 'N')
         INTO V_ESTQTERC, V_TIPMOV, V_AD_TOPVALRET
         FROM TGFTOP
         WHERE TGFTOP.CODTIPOPER = V_CODTIPOPER
         AND   TGFTOP.DHALTER   = (select max(dhalter) from tgftop where codtipoper = V_CODTIPOPER) ;


       IF( V_ESTQTERC in ('R', 'P') AND (V_AD_TOPVALRET = 'S')  ) then

/*           -- Verifica se o produto tem rastro de lote ou não para consultar o estoque do item
            SELECT TEMRASTROLOTE INTO V_TEMRASTROLOTE
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
            IF V_ESTOQUE > v_RESERVADO THEN
               V_SALDO := V_ESTOQUE - V_RESERVADO;
            ELSE
               V_SALDO :=  V_ESTOQUE ;
            END IF;
*/
            IF( :NEW.CODPROD <> :OLD.CODPROD)  THEN
                           raise_application_error(-20101,
                           fc_formatahtml(p_mensagem => ' Não é permitido alterar o PRODUTO em notas de retorno. Se preciso exclua o item e inclua o item novo.' ,
                                          p_motivo   => ' Nota movimenta estoque de terceiro e está configurada para validar retorno na TOP' ,
                                          p_solucao  => ' Alteração não permitida'));

             END IF;


/*            IF( :NEW.CODLOCALORIG <> :OLD.CODLOCALORIG)  THEN
                           raise_application_error(-20101,
                           fc_formatahtml(p_mensagem => ' Não é permitido alterar o LOCAL em notas de retorno. Se preciso exclua o item e inclua o item novo.' ,
                                          p_motivo   => ' Nota movimenta estoque de terceiro e está configurada para validar retorno na TOP' ,
                                          p_solucao  => ' Alteração não permitida'));

             END IF;
*/

          /*  IF( :NEW.CONTROLE <> :OLD.CONTROLE)  THEN
                           raise_application_error(-20101,
                           fc_formatahtml(p_mensagem => ' Não é permitido alterar o LOTE em notas de retorno. Se preciso exclua o item e inclua o item novo.' ,
                                          p_motivo   => ' Nota movimenta estoque de terceiro e está configurada para validar retorno na TOP' ,
                                          p_solucao  => ' Alteração não permitida'));

             END IF; */


  /*          IF( :NEW.QTDNEG <> :OLD.QTDNEG)  THEN
                           raise_application_error(-20101,
                           fc_formatahtml(p_mensagem => ' Não é permitido alterar a QUANTIDADE em notas de retorno. Se preciso exclua o item e inclua o item novo.' ,
                                          p_motivo   => ' Nota movimenta estoque de terceiro e está configurada para validar retorno na TOP' ,
                                          p_solucao  => ' Alteração não permitida'));

             END IF;
      */       
        END IF;
END;
