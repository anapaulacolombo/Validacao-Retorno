Plano de Deploy
1a. Criação do campo na TGFITE AD_DIVERG_IMP (Divergências Importação ?) - ok
2a. Criada trigger AD_TRG_TGFCAB_VAL_RETORNO_V2
3a. Criada trigger AD_TRG_TGFITE_VAL_RETORNO_V2
4a. Criada trigger AD_TRG_TGFITE_VAL_RETORNO_V3
5a. Criada procedure AD_STP_VAL_DIVERG
7 - Ajustar layouts colocar campo de divergencia:
* Nota fiscal entrada naciona - OK
* Nota fiscal remessa - OK

8. Criar o botão Valida divergencia  - TGFITE

6. Alterar as tops de retorno para não permitir alterar depois de confirmadas

UPDATE TGFTOP
SET   ALTNFCONF = 'N',
      AD_TOPNAOVALRET = 'S'
WHERE CODTIPOPER IN (2160, 2912, 3312, 3782, 2229, 2106, 3314, 3780, 3792, 3793, 3320, 2914, 3319, 2204, 3791, 6000, 
                      2155, 3315, 2243, 3782, 3900, 2161, 2251, 3791, 2156, 2158, 2252, 2119, 2208, 3316, 2219, 2150,
                      2238, 2282, 2214, 2235, 3322, 2231, 2233, 2148, 2163, 3317, 2234, 2211, 2149, 2151, 3902, 2140)

*******************************************************************
Histórico do desenvolvimento

A validação de estoque se tem quantidade disponivel do produto, lote e local é feita pela trigger AD_TRG_TGFEST_VALIDAEST

1a. Alteração AD_TRG_TGFCAB_VAL_RETORNO - buscar a última versão da top, pois se estiver usando uma versão anterior pode não estar validando.

       SELECT DISTINCT ATUALESTTERC , TIPMOV, NVL(AD_TOPNAOVALRET, 'N'), DHALTER
         FROM TGFTOP
         WHERE TGFTOP.CODTIPOPER = 3320   
         AND   TGFTOP.DHALTER    = (select max(dhalter) from tgftop where codtipoper = 3320)



Dúvidas:
1 - Verificar se existem casos que controla saldo de terceiro e que não deve validar retorno. Se não tiver pode tirar parametro. Mantive parametro.
2-  Toda validação de estoque de retornar produtos que existam na TGFEST é validado pela procedure AD_TRG_TGFEST_VALIDAEST
3-  Quando o produto, local, lote não exite na TGFEST então passa pela trigger AD_TRG_TGFCAB_VAL_RETORNO_V2, para realizar a validação.


Hom@2024


select * from tgfcab
where tgfcab.chavenfe = '35250277058881000550550020000044001000200999'

SELECT * FROM TGFITE WHERE NUNOTA = 805913

select * from tgfloc

SELECT ESTOQUE
FROM TGFEST EST
WHERE EST.CODEMP = 6
AND   EST.CODPROD = 8082
AND   EST.CONTROLE = '173896/1'
AND   EST.CODLOCAL = 21100
AND   EST.CODPARC = 9205


SELECT ITE.CODPROD, SUM(ITE.QTDNEG)as QTDNEG, ITE.CONTROLE, ITE.CODLOCALORIG,
       PRO.DESCRPROD, PRO.TEMRASTROLOTE
FROM TGFITE ITE, TGFPRO PRO
WHERE ITE.CODPROD = PRO.CODPROD
AND NUNOTA = 793775
GROUP BY ITE.CODPROD, ITE.CONTROLE, ITE.CODLOCALORIG,
       PRO.DESCRPROD, PRO.TEMRASTROLOTE


select *
from all_source
where (text) like '%AD_ITECONFIRMADO%'


update tsilib 
set dhlib = sysdate, 
    codusulib = 58, vlrliberado = 1800, obslib = 'liberado'
where nuchave = 793801 and evento = 44;

select * from tsilib
where nuchave = 793801 and evento = 44;

 SELECT ITE.CODPROD, SUM(ITE.QTDNEG) as QUANTIDADE, ITE.CONTROLE, ITE.CODLOCALORIG,

                           PRO.DESCRPROD, PRO.TEMRASTROLOTE
                             FROM TGFITE ITE, TGFPRO PRO
                            WHERE  ITE.CODPROD = PRO.CODPROD
                            AND NUNOTA = 805862
                            GROUP BY ITE.CODPROD, ITE.CONTROLE, ITE.CODLOCALORIG,
             
