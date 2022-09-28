/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
-- script get data run on SiteDB
declare @transid varchar(max) = ''

select @transid = @transid + cast(transid as varchar(30)) + ','
from bettrans s with(nolock)
where statusID = 103
and modds is null
and transid in (select c.transid from dbctg.bodb02.dbo.bettrans c with(nolock) where c.transid = s.transid and c.statusid = 103 and c.modds is not null)
order by transid

select @transid

*/

-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
AS
/*
	Created by: 20220923@Victoria
    Task: Delete unused test data of BetRadar
    DB: DBCTG-bodb02

	 Revisions:
		- 20220923@Victoria: Delete unused test data of BetRadar [Redmineid:#178134] 
		- 20220927@Kathy: Bettrans.modds difference between Central & SiteDB  [Redmineid:#178189] 

*/	

BEGIN

	UPDATE b
		SET modds = NULL
	FROM	dbo.bettrans b WITH (ROWLOCK)
	WHERE	b.TransId IN (31312716773720064,31312733953589248,31312798378098690,31313133385547785,31313257939599360,31313532817506304,31313549997375488,32030667801886720,32054238582407168,32058241491927060,32068068377100289,32085256836218880,32164524752633856,32364532789673984,32382739156041735)
			AND b.modds IS NOT NULL
			AND b.statusID = 103

END
GO
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY ------------------------------------------
EXEC ExecRep_NAP_Admin_09