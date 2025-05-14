--ALTER SESSION SET CURRENT_SCHEMA=SANKHYA;

                       
CREATE OR REPLACE PROCEDURE AD_STP_VAL_DIVERG (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       FIELD_NUNOTA     NUMBER;
       FIELD_SEQUENCIA  NUMBER;
       FIELD_CODPROD    NUMBER;
       V_TIPMOV         VARCHAR(10);
       V_NUNOTA         TGFCAB.NUNOTA%TYPE;
       V_TEMRASTROLOTE  TGFPRO.TEMRASTROLOTE%TYPE;
       V_QUANTIDADE     TGFITE.QTDNEG%TYPE;
       V_CONTROLE       TGFITE.CONTROLE%tYPE;
       V_CODLOCALORIG   TGFITE.CODLOCALORIG%TYPE;
       V_CODEMP         TGFCAB.CODEMP%TYPE;
       V_CODPARC        TGFCAB.CODPARC%TYPE;
       V_DESCRPROD      TGFPRO.DESCRPROD%TYPE;
       V_CODTIPOPER     TGFCAB.CODTIPOPER%TYPE;
       V_ESTQTERC       TGFTOP.ATUALESTTERC%TYPE;
       V_AD_TOPVALRET   TGFTOP.AD_TOPVALRET%tYPE;
       V_ESTOQUE        TGFEST.ESTOQUE%TYPE;
       V_CODPROD        TGFITE.CODPROD%TYPE;
       V_RESERVADO      TGFEST.ESTOQUE%TYPE;
       V_SALDO          TGFEST.ESTOQUE%TYPE;
       V_CODVOL         TGFITE.CODVOL%TYPE;
       V_CONT           INTEGER;

BEGIN

/************************************************************************************************************
-- Task [Logistica] PE2.48 - Validar Vencimento e Lote Inativo na rotina de transferencia entre locais
https://grupoboticario.kanbanize.com/ctrl_board/301/cards/1188425/details/

---Criado por Ana Paula Colombo em 25/02/25
-- Objetivo:  Não permitir retornar produtos sem saldo de remessa ou de lotes que não foram enviados
-- Nesta trigger não permite alterar a quantidade em notas de retorno
*************************************************************************************************************/
    V_SALDO:= 0;

    FOR I IN 1..P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
    LOOP

           FIELD_NUNOTA    := ACT_INT_FIELD(P_IDSESSAO, I, 'NUNOTA');
           FIELD_CODPROD   := ACT_INT_FIELD(P_IDSESSAO, I, 'CODPROD');
           FIELD_SEQUENCIA := ACT_INT_FIELD(P_IDSESSAO, I, 'SEQUENCIA');

           SELECT  ITE.CODPROD,  ITE.QTDNEG as QUANTIDADE, ITE.CONTROLE, ITE.CODLOCALORIG,
                   CAB.NUNOTA, CAB.TIPMOV, CAB.CODTIPOPER, ITE.CODVOL, 
                   CAB.CODEMP, CAB.CODPARC, PRO.DESCRPROD, NVL(PRO.TEMRASTROLOTE, 'N') AS TEMRASTROLOTE
                   
           INTO    V_CODPROD, V_QUANTIDADE, V_CONTROLE, V_CODLOCALORIG,
                   V_NUNOTA, V_TIPMOV, V_CODTIPOPER, V_CODVOL,
                   V_CODEMP, V_CODPARC, V_DESCRPROD, V_TEMRASTROLOTE

           FROM TGFCAB CAB, TGFITE ITE, TGFPRO PRO
           WHERE  CAB.NUNOTA    = ITE.NUNOTA
           AND    ITE.CODPROD   = PRO.CODPROD
           AND    CAB.NUNOTA    = FIELD_NUNOTA
           AND    ITE.SEQUENCIA = FIELD_SEQUENCIA;


         IF V_TIPMOV <> 'C' THEN
            RAISE_APPLICATION_ERROR(-20101, '<b>Ação permitida apenas para notas de compra.</b>');
         END IF;


         SELECT DISTINCT ATUALESTTERC ,  NVL(AD_TOPVALRET, 'N')
         INTO V_ESTQTERC, V_AD_TOPVALRET
         FROM TGFTOP
         WHERE TGFTOP.CODTIPOPER = V_CODTIPOPER
         AND   TGFTOP.DHALTER   = (select max(dhalter) from tgftop where codtipoper = V_CODTIPOPER) ;


              --- VERIFICA SE A TOP ESTÁ CONFIGURADA COMO "SUBTRAI ESTOQUE PROPRIO EM PODER DE TERCEIRO" OU
              -- "soma estoque proprio em proder de terceiro" , então valida empresa
              -- validar apenas se o parametro "Não valida retorno <> 'S'
              IF( V_ESTQTERC in ('R', 'P') AND (V_AD_TOPVALRET = 'S')) THEN

                    IF V_TEMRASTROLOTE = 'S' THEN
                       -- VERIFICA SE HÁ ESTOQUE DE TERCEIRO DO PRODUTO, LOCAL, CONTROLE E PARCEIRO INFORMADO
                        SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                          INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = V_CODEMP
                        AND   EST.CODPARC = V_CODPARC
                        AND   EST.CODPROD = V_CODPROD
                        AND   EST.CONTROLE = V_CONTROLE
                        AND   EST.CODLOCAL = V_CODLOCALORIG;
                    ELSE
                        SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                          INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = V_CODEMP
                        AND   EST.CODPARC = V_CODPARC
                        AND   EST.CODPROD = V_CODPROD
                        AND   EST.CODLOCAL = V_CODLOCALORIG;

                    END IF;
                     -- Calcula o saldo disponivel
                    IF V_ESTOQUE > V_RESERVADO THEN
                        V_SALDO := V_ESTOQUE - V_RESERVADO;
                    ELSE
                         V_SALDO :=  V_ESTOQUE ;
                    END IF;

                    -- SE NÃO HOUVER LINHA TGFEST SIGNIFICA QUE NÃO HÁ SALDO PARA DEVOLVER
                    IF ((V_SALDO = 0 ) OR (V_SALDO < 0) or (V_SALDO < V_QUANTIDADE)) THEN
                             raise_application_error(-20101,
                                       fc_formatahtml(p_mensagem => ' Verifique o item '|| FIELD_SEQUENCIA ||' - ' || V_CODPROD || '- ' || V_DESCRPROD ||'  Lote: ' || V_CONTROLE || '  Local: ' ||V_CODLOCALORIG ||' Empresa: ' ||V_CODEMP ||' Parceiro: ' ||V_CODPARC   ,
                                                      p_motivo   => ' Não tem saldo de remessa para retornar esse item.' || ' Estoque = ' || V_SALDO || '  Qtde na NF :' || V_QUANTIDADE ,
                                                      p_solucao  => ' Nota não pode ser finalizada. Verfique o saldo do produto no relatório: Estoque por Local Lote e Parceiro'));

                    ELSE
                         UPDATE TGFITE
                         SET   TGFITE.Ad_Diverg_Imp = 'N'
                         WHERE  NUNOTA    = FIELD_NUNOTA
                         AND    SEQUENCIA = FIELD_SEQUENCIA;
                         
                         
                         SELECT NVL(COUNT(1),0)  INTO V_CONT
                         FROM AD_LOGNOTA
                          WHERE NUNOTA  = FIELD_NUNOTA
                         AND SEQ       = FIELD_SEQUENCIA
                         AND CODPROD   = V_CODPROD;
                         
                         IF V_CONT > 0 THEN
                            
                            -- Atualiza tabela de LOG quando a divergência foi corrigida
                            UPDATE AD_LOGNOTA
                            SET LOTEALT     = V_CONTROLE,
                                CODLOCALALT = V_CODLOCALORIG,
                                UNIDADEALT  = V_CODVOL,
                                CODUSU      = STP_GET_CODUSULOGADO,
                                QTDEALT     = V_QUANTIDADE,
                                DHALTERACAO = SYSDATE
                             WHERE NUNOTA  = FIELD_NUNOTA
                             AND SEQ       = FIELD_SEQUENCIA
                             AND CODPROD   = V_CODPROD;
                             
                         END IF;

                    END IF;
          END IF;

      END LOOP;
      P_MENSAGEM := 'Validação realizada com sucesso.';




END;
