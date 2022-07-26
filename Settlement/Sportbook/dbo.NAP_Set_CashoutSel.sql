/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_CashoutSel]
	@MatchId INT
	,@SelectedResources VARCHAR(MAX)
AS
/*
	Created by: 20220531@Kathy
	Task: get list CO ticket [Redmine:#173361]
	DB:DBTXN.BODB02

	Revisions:
		- 20220531@Kathy: get list CO ticket [Redmine:#173361]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" />
									<Resource Id="M2" />
							   </Resources>'
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @handle	INT
	DECLARE @tmpResources TABLE(ResourceID VARCHAR(20), Bettype SMALLINT, BetId BIGINT)

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResources(ResourceID, Bettype, BetId)
	SELECT Id, sp.BetType, sp.BetID
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)														
										) AS tbl
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			ON sp.ResourceID = tbl.Id
	WHERE	sp.SportType = 2
			
	EXEC sp_xml_removedocument @handle

	SELECT	b.transid, b.custid, b.statusID
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	b.matchid = @MatchId
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			AND ISNULL(b.betdaqid,0) = -2
			AND EXISTS (SELECT TOP 1 1 FROM @tmpResources t WHERE t.Bettype = b.bettype AND (t.BetId = 0 OR t.BetId = b.betid ))
			AND b.statusID <> 102
END


GO


