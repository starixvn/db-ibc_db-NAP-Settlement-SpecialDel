/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_SettlementStatusChecking]
	@MatchId	INT
	,@Action	VARCHAR(20)
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(300) = '' OUTPUT
AS
/*
	Created: Kathy
	Date: 20200724
	Task : check settlement status
	DB: DBPRO/bodb02

	Revisions:
		- 20200724@Kathy: Prevent Refund Wrong Match by Checking Settlement Status [Redmine:#136390]
		
	Parameters Explanation:    
		@Action: CAL

		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @SettlementStatus TINYINT

	SELECT	@SettlementStatus = m.SettlementStatus
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
	
	IF @SettlementStatus & 32 > 0
	BEGIN
		IF @Action LIKE 'CAL%'
		BEGIN
    		SELECT	@ErrCode = 1001033
					,@ErrMsg = 'WARNING! Cannot proceed due to this match is marked for Refund All.	'
		END
		ELSE IF @Action = 'REFUND'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.odds o WITH(NOLOCK) WHERE o.liveindicator = 1 AND o.oddsstatus <> 'closed') 	-- check running odds
				SELECT	@ErrCode = 1001035
						,@ErrMsg = 'WARNING! Cannot proceed due to running odds. Please close them all and try again.'
		END
    END
	ELSE
	BEGIN
		IF @Action = 'REFUND'
			SELECT	@ErrCode = 1001034
					,@ErrMsg = 'WARNING! Cannot proceed due to this match is NOT marked for Refund All.'

	END
END
GO
