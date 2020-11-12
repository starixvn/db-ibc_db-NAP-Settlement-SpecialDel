/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_HoldSettingChecking
	@MatchId	INT
	,@Action	VARCHAR(20) = 'CAL'
	,@IsEarly	BIT = 0
	,@SelectedResources VARCHAR(MAX) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(200) = '' OUTPUT
AS
/*
	Created by: 20201111@Louisa
	Task	: Check Hold setting [Redmine:#143441]
	DB		: DBPRO/bodb02

	Revisions:
		-  20201111@Louisa: Check Hold setting [Redmine:#143441]

		
	Parameters Explanation:    
		@IsEarly = 0 : Check dbo.Match.SettlementStatus bit[1]-Pending, bit[2]-Undecided, bit[3]-UnderSettlement, bit[5]-MTDHold, bit[7]-Hold Key
		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @SettlementStatus TINYINT
			,@Sporrtype TINYINT
			,@handle INT
	
	
	DECLARE @tmpResourceID TABLE ( ResourceID VARCHAR(20) )
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpResourceID(ResourceID)
	SELECT DISTINCT Id	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20) ) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT @Sporrtype = m.Sporttype 
			,@SettlementStatus = m.SettlementStatus
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.Matchid =  @MatchId

	
	IF @SettlementStatus & 87 > 0
	BEGIN
		SELECT	@ErrCode = 1001038	,@ErrMsg = 'Cannot proceed due to this match is Holding.	'
	END

END
GO