/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ResultConfirmRefundSel
	 @MatchId		INT 
	,@SourceId		SMALLINT	= 99
AS
/*
    Created by: 20230515@Aries
    Task: Apply Settle Determined for Basketball [Redmine:#175202]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20241111@Louisa: Refund SDT Baseball (Mercyrule) - [Redmine:#212365]
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
			,@ExternalResultTable TINYINT

	SELECT @SportType = m.sporttype 
	FROM match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

	SELECT @ExternalResultTable = s.ExternalResultTable
	FROM dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE s.Sporttype = @Sporttype

	IF @ExternalResultTable = 1
	BEGIN
		SELECT	 p.MatchId
				,p.ResourceId
				,p.HomeValue
				,p.AwayValue
				,p.SourceID
				,p.CreateDate
				,p.CreateBy
				,p.LastModifyDate
				,p.LastModifyBy
				,p.OtherInfo
		FROM	dbo.ProviderExternalResultDetail p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId 
			AND p.SourceId = @SourceId
	END
	ELSE IF @ExternalResultTable = 2
	BEGIN
		SELECT	 p.MatchId
				,p.ResourceId
				,p.HomeValue
				,p.AwayValue
				,p.SourceID
				,p.CreateDate
				,p.CreateBy
				,p.LastModifyDate
				,p.LastModifyBy
				,p.OtherInfo
		FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId 
			AND p.SourceId = @SourceId
	END
END
GO