/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: Basketball Player Prop - Bettype Performance/Other/Most [Redmine:#233012]
*/
 
USE bodb02
GO

BEGIN
	DECLARE @Relate_669 VARCHAR(20)
			,@Relate_671 VARCHAR(20)
			,@Relate_673 VARCHAR(20)
			,@Relate_674 VARCHAR(20)
			,@Relate_675 VARCHAR(20)
			,@Relate_676 VARCHAR(20)
			,@Relate_678 VARCHAR(20)
			,@Relate_677 VARCHAR(20)
			,@Relate_679 VARCHAR(20)
			,@Relate_680 VARCHAR(20)
			,@Relate_681 VARCHAR(20)
			,@Relate_682 VARCHAR(20)
			,@Relate_683 VARCHAR(20)
			,@Relate_684 VARCHAR(20)
	
	SELECT @Relate_669  = SELECT ResourceID
						  FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
						  WHERE sp.Sporttype = 2
							AND sp.SettleType = 'EAR'


	UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '65301')
	WHERE SportType = 2
		AND ResourceID like '390301%'

END
GO