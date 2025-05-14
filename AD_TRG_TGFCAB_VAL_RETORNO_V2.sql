--ALTER SESSION SET CURRENT_SCHEMA=SANKHYA;

CREATE OR REPLACE TRIGGER AD_TRG_TGFCAB_VAL_RETORNO_V2
BEFORE UPDATE ON TGFCAB
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

declare

V_ESTQTERC         TGFTOP.ATUALESTTERC%TYPE;
V_TIPMOV           TGFTOP.TIPMOV%TYPE;
V_AD_TOPVALRET  TGFTOP.AD_TOPVALRET%tYPE;
V_ESTOQUE          TGFEST.ESTOQUE%TYPE;
V_RESERVADO        TGFEST.ESTOQUE%TYPE;
V_SALDO            TGFEST.ESTOQUE%TYPE;
V_TEM_DIVERGENCIA  INT;

PRAGMA AUTONOMOUS_TRANSACTION;

/************************************************************************************************************
-- Task [Logistica] PE2.48 - Validar Vencimento e Lote Inativo na rotina de transferencia entre locais
https://grupoboticario.kanbanize.com/ctrl_board/301/cards/1188425/details/

---Criado por Ana Paula Colombo em 25/02/25
-- Objetivo:  Não permitir retornar produtos sem saldo de remessa ou de lotes que não foram enviados
*************************************************************************************************************/
BEGIN

IF DELETING  THEN
  RETURN;
END IF;

-- Valida apenas na confirmação da nota, pelo portal não valida
IF (:OLD.STATUSNOTA <> 'L' AND :NEW.STATUSNOTA = 'L') THEN

    IF ( UPDATING AND  :NEW.NUNOTA >0 AND :NEW.CODTIPOPER > 0 )   THEN

         SELECT DISTINCT ATUALESTTERC , TIPMOV, NVL(AD_TOPVALRET, 'N')
         INTO V_ESTQTERC, V_TIPMOV, V_AD_TOPVALRET
         FROM TGFTOP
         WHERE TGFTOP.CODTIPOPER = :NEW.CODTIPOPER
         AND   TGFTOP.DHALTER   = (select max(dhalter) from tgftop where codtipoper = :NEW.CODTIPOPER) ;


         SELECT COUNT(1) INTO  V_TEM_DIVERGENCIA
         FROM TGFITE
         WHERE NUNOTA =:NEW.NUNOTA
         AND  AD_DIVERG_IMP = 'S';


         IF V_TEM_DIVERGENCIA = 0 THEN
              --- VERIFICA SE A TOP ESTÁ CONFIGURADA COMO "SUBTRAI ESTOQUE PROPRIO EM PODER DE TERCEIRO" OU
              -- "soma estoque proprio em proder de terceiro" , então valida empresa
              -- validar apenas se o parametro "Não valida retorno <> 'S'
              IF( V_ESTQTERC in ('R', 'P') AND (V_AD_TOPVALRET = 'S')) then

                 FOR regI IN ( SELECT  ITE.CODPROD, SUM(ITE.QTDNEG) as QUANTIDADE, ITE.CONTROLE, ITE.CODLOCALORIG,
                                       ITE.CODEMP,
                                       PRO.DESCRPROD, NVL(PRO.TEMRASTROLOTE, 'N') AS TEMRASTROLOTE
                                 FROM TGFITE ITE, TGFPRO PRO
                                WHERE  ITE.CODPROD = PRO.CODPROD
                                AND    ITE.NUNOTA = :NEW.NUNOTA
                                GROUP BY ITE.CODPROD, ITE.CONTROLE, ITE.CODLOCALORIG, ITE.CODEMP,
                                         PRO.DESCRPROD, PRO.TEMRASTROLOTE)
                 LOOP

                    IF regI.TEMRASTROLOTE = 'S' THEN
                       -- VERIFICA SE HÁ ESTOQUE DE TERCEIRO DO PRODUTO, LOCAL, CONTROLE E PARCEIRO INFORMADO
                       SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                        INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = regI.CODEMP
                        AND   EST.CODPARC = :NEW.CODPARC
                        AND   EST.CODPROD = regI.CODPROD
                        AND   EST.CONTROLE = regI.CONTROLE
                        AND   EST.CODLOCAL = regI.CODLOCALORIG;
                    ELSE
                        SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                        INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = regI.CODEMP
                        AND   EST.CODPARC = :NEW.CODPARC
                        AND   EST.CODPROD = regI.CODPROD
                        AND   EST.CODLOCAL = regI.CODLOCALORIG;

                    END IF;
                     -- Calcula o saldo disponivel
                      IF V_ESTOQUE > v_RESERVADO THEN
                         V_SALDO := V_ESTOQUE - V_RESERVADO;
                      ELSE
                         V_SALDO :=  V_ESTOQUE ;
                      END IF;


                    -- SE NÃO HOUVER LINHA TGFEST SIGNIFICA QUE NÃO HÁ SALDO PARA DEVOLVER
                    IF ((V_SALDO = 0 ) OR (V_SALDO < 0) or (V_SALDO < regI.QUANTIDADE)) THEN
                             raise_application_error(-20101,
                                       fc_formatahtml(p_mensagem => ' Verifique o item ' || regI.CODPROD || '- ' || regI.DESCRPROD ||'  Lote: ' || regI.CONTROLE || '  Local: ' ||regI.CODLOCALORIG ||' Empresa: ' ||regI.CODEMP ||' Parceiro: ' ||:NEW.CODPARC   ,
                                                      p_motivo   => ' Não tem saldo de remessa para retornar esse item.' || ' Estoque = ' || V_SALDO || '  Qtde na NF :' || regI.QUANTIDADE ,
                                                      p_solucao  => ' Nota não pode ser finalizada. Verfique o saldo do produto no relatório: Estoque por Local Lote e Parceiro'));


                    END IF;

                  END LOOP;

               END IF; --1

           ELSE
                raise_application_error(-20101,
                         fc_formatahtml(p_mensagem => ' Itens com divergência !' ,
                                        p_motivo   => ' Verifique antes de continuar.',
                                        p_solucao  => ' Nota não pode ser finalizada. Verfique o saldo do produto no relatório: Estoque por Local Lote e Parceiro'));
           END IF;

     END IF;
END IF;

END;
