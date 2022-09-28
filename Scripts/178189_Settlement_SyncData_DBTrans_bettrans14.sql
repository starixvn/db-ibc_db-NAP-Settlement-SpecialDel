/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/


/*
-- script to get data: run on sitedb
declare @transid varchar(max) = ''

select @transid = @transid + cast(transid as varchar(30)) + ','
select modds, bettype, *
from bettrans14 s with(nolock)
where statusID = 103
and modds is null
and transid in (select c.transid from dbctg.bodb02.dbo.bettrans14 c with(nolock) where c.transid = s.transid and c.statusid = 103 and c.modds is not null)
order by transid

select @transid

*/
-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
ALTER PROCEDURE [dbo].[Bet_ExecRep14_00]
AS
/*
	Created by: 20220927@Kathy
    Task: update data
    DB: DBCTG-bodb02

	 Revisions:
		- 20220927@Kathy: Bettrans.modds difference between Central & SiteDB  [Redmineid:#178189] 

*/	

BEGIN
	UPDATE b
		SET modds = NULL
	FROM	dbo.bettrans14 b WITH (ROWLOCK)
	WHERE	b.TransId IN (28233736323596288,29782454285893632,31137705446342656,31302683730116610,31342687055511552,31342974818320384,31421727338659840,31481264175316998,31481281355186176,31485816840650752,31570500710825988,31573056216367104,31596944824467456,31756275226247168,31774808010129408,31851619205251072,31869842751488000,31874300927541248,31874975237406720)
			AND b.modds IS NOT NULL
			AND b.statusID = 103
			
END
GO

-----------STEP 2: NEED TO RUN ON DBTRANS ONLY ------------------------------------------
EXEC Bet_ExecRep14_00