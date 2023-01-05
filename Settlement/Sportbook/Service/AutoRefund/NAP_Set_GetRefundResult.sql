/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_GetRefundResult
	@MatchId				INT
	,@Sporttype				TINYINT			= 9
	,@TypeId				TINYINT			= 1
	,@CalculateResources	VARCHAR(MAX)	
	,@ResourceRefund		VARCHAR(100)	= ''	OUTPUT
AS
/*
	Creator: 20220512@Louisa
	Task: Auto refund Badminton [Redmine:#171676]
	DB: DBTXN/bodb02

	Revisions:
		- 20220512@Louisa: Initial [Redmine:#171676]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]

	Param's explaination: 
		- @TypeId:  1 - Auto refund single or sporttype apply merge single + parlay
				   10 - Auto refund parlay

		- @CalculateResources:   '<Resources>				
	 								<Resource Id="0101" Home="25" Away="10" />
		 							<Resource Id="0102" Home="25" Away="10"  />
									<Resource Id="00" Home="2" Away="0" />
		 						</Resources>'

*/

BEGIN

	SET NOCOUNT ON

	DECLARE @handle INT
		
	DECLARE @tmpCalculateResources TABLE(ResourceId VARCHAR(20) )
	DECLARE @tmpResourceAutoRefund TABLE ( ResourceId VARCHAR(20) , bettype SMALLINT, betid BIGINT, IsExistsTicket BIT )

	IF ISNULL(@CalculateResources, '') = '' 
		RETURN

	EXEC sp_xml_preparedocument @handle OUTPUT, @CalculateResources
	
	INSERT INTO @tmpCalculateResources (ResourceId)
	SELECT Id
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)	) AS tbl
	
	EXEC sp_xml_removedocument @handle

	INSERT INTO @tmpResourceAutoRefund ( ResourceId, bettype, betid, IsExistsTicket ) 
	SELECT DISTINCT sp.ResourceID, sp.Bettype, sp.BetID, 0
	FROM dbo.SettlementSpecialBettypeProfile sp (NOLOCK)
		LEFT JOIN @tmpCalculateResources r ON sp.ResourceID = r.ResourceId
	WHERE sp.SportType = @sportType
		AND sp.SettleType = 'MNL'
		AND r.ResourceID IS NULL
		AND EXISTS (SELECT TOP 1 1 FROM f_Set_MajorRound(@Sporttype) f WHERE f.GroupType = 'SP' AND (f.ResourceID = sp.ResourceID OR f.ResourceID = sp.RefResourceId))
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResourceAutoRefund)
		RETURN

	UPDATE r
	SET r.IsExistsTicket = 1
	FROM @tmpResourceAutoRefund r
		CROSS APPLY (	SELECT TOP 1 b.transid FROM dbo.bettrans b (NOLOCK)
						 WHERE b.matchid =  @matchid
						 AND r.Bettype = b.Bettype AND (r.betid =  0 OR b.betid =  r.betid)
					 ) b

	UPDATE r
	SET r.IsExistsTicket = 1
	FROM @tmpResourceAutoRefund r
		CROSS APPLY (	SELECT TOP 1 bm.transid FROM dbo.bettransm bm (NOLOCK)
						 WHERE bm.matchid =  @matchid
						 AND r.Bettype = bm.Bettype AND (r.betid =  0 OR bm.betcheck =  r.betid)
					 )	bm
	WHERE r.IsExistsTicket = 0
		
	SELECT @ResourceRefund =  @ResourceRefund + ','   + r.ResourceID 
	FROM (	SELECT DISTINCT ResourceId FROM @tmpResourceAutoRefund WHERE IsExistsTicket = 1 ) r

	SET @ResourceRefund = SUBSTRING(@ResourceRefund, 2, LEN(@ResourceRefund))

END
GO