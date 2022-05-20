/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_GetAutoRefundOSResult
	@MatchId				INT
	,@Sporttype				TINYINT			= 9
	,@TypeId				TINYINT			= 1
	,@CalculateResources	VARCHAR(500)	
	,@ResourceRefund		VARCHAR(100)	= ''	OUTPUT
AS
/*
	Creator: 20220512@Louisa
	Task: Auto refund Badminton [Redmine:#171676]
	DB: DBTXN/bodb02

	Revisions:
		- 20220512@Louisa: Initial [Redmine:#171676]

	Param's explaination: 
		- @TypeId:  1 - Auto refund single
				   10 - Auto refund parlay

*/

BEGIN

	SET NOCOUNT ON

	DECLARE @handle INT
	DECLARE @tmpCalculateResources TABLE(ResourceId VARCHAR(20) )
	DECLARE @tmpResourceAutoRefund TABLE ( ResourceId VARCHAR(20) , bettype TINYINT )

	IF @Sporttype <> 9
	RETURN

	IF ISNULL(@CalculateResources, '') = '' 
		RETURN

	EXEC sp_xml_preparedocument @handle OUTPUT, @CalculateResources
	
	INSERT INTO @tmpCalculateResources (ResourceId)
	SELECT Id
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)	) AS tbl
	
	EXEC sp_xml_removedocument @handle

	INSERT INTO @tmpResourceAutoRefund ( ResourceId, bettype ) 
	SELECT DISTINCT sp.ResourceID, sp.Bettype
	FROM dbo.SettlementSpecialBettypeProfile sp (NOLOCK)
		LEFT JOIN @tmpCalculateResources r ON sp.ResourceID = r.ResourceId
	WHERE sp.SportType = @sportType
		AND sp.SettleType ='MNL'
		AND r.ResourceID IS NULL

	--if not exists resourceid can refund
	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResourceAutoRefund)
		RETURN

	IF EXISTS (	SELECT TOP 1 1 FROM dbo.bettrans b (NOLOCK) 
				INNER JOIN @tmpResourceAutoRefund r ON r.Bettype = b.Bettype
				WHERE b.matchid =  @matchid AND b.statusId = 0	
				)
	BEGIN
		SELECT @ResourceRefund =  @ResourceRefund + ','   + ResourceID FROM @tmpResourceAutoRefund
		RETURN
	END

	IF EXISTS (	SELECT TOP 1 1 FROM dbo.bettransm b (NOLOCK) 
				INNER JOIN @tmpResourceAutoRefund r ON r.Bettype = b.Bettype
				WHERE b.matchid =  @matchid AND b.statusId = 0 	
				)
	BEGIN
		SELECT @ResourceRefund =  @ResourceRefund + ','   + ResourceID FROM @tmpResourceAutoRefund
		RETURN
	END

	
END
GO