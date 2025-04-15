/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementLog_Ins]
	@MatchID				INT				=	NULL,
	@SportType 				INT				=	NULL,
	@Action					VARCHAR(20)		=	NULL,
	@Mode					VARCHAR(20)		=	'',
	@IsAuto					BIT				=	0,
	@AdminID				INT				=	NULL,
	@SelectedResources		VARCHAR(MAX)	=	NULL
AS
/*	
	Creator: 20230414@Aries
	Task: Support OST Team Query Resettlement Log [Redmine: #185964]
	DB: DBLOG/bodb_CustomerLog
	 
	Revisions:
		-	20230414@Aries: Created [Redmine:#185964]
		-	20250415@Aries: Settle - Integrate - Result Amendment - Fast Markets, Time Machine, ＆ Bet Builder [Redmine:#223456]
		
	Param's Explanation:
		-   @IsAuto = 1 When action from NAP_Admin_Settlement_Auto_1s_Push
*/
BEGIN
    SET NOCOUNT ON;
	DECLARE		@handle				INT,
				@ActionID			INT
	DECLARE		@tmpResourcesWeb	TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OtherInfo VARCHAR(2000))

	SELECT  @ActionID = CASE			  
						  WHEN @Mode = '' AND @Action = 'CAL' AND @IsAuto =0		THEN 100
						  WHEN @Mode = '' AND @Action = 'CAL' AND @IsAuto =1		THEN 148 
						  WHEN @Mode = '' AND @Action = 'CAL-FT'					THEN 101
						  WHEN @Mode = '' AND @Action = 'CAL-HT'					THEN 102
						  WHEN @Mode = '' AND @Action = 'CAL_EAR'					THEN 189

						  WHEN @Mode = '' AND @Action = 'UNDO' AND @IsAuto =0		THEN 103
						  WHEN @Mode = '' AND @Action = 'UNDO'	AND @IsAuto =1		THEN 149 
						  WHEN @Mode = '' AND @Action = 'UNDO_EAR'					THEN 190
						  WHEN @Mode = '' AND @Action = 'UNDO-FT'					THEN 81040

						  WHEN @Mode = '' AND @Action = 'REFUND' AND @IsAuto =0		THEN 109
						  WHEN @Mode = '' AND @Action = 'REFUND' AND @IsAuto =1		THEN 150
						  WHEN @Mode = '' AND @Action = 'REFUND_EAR'				THEN 191
						  WHEN @Mode = '' AND @Action = 'REFUND-HT'					THEN 110
						  WHEN @Mode = '' AND @Action = 'REFUND-FT'					THEN 111
						  
						  WHEN @Mode = 'FM' AND @Action = 'CAL' 					THEN 165
						  WHEN @Mode = 'FM' AND @Action = 'UNDO' 					THEN 166
						  WHEN @Mode = 'FM' AND @Action = 'REFUND' 					THEN 167
						  ELSE 0
					   END

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue,OtherInfo)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''),OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(	 Id				VARCHAR(20)
														,Home			VARCHAR(50)
														,Away			VARCHAR(50)
														,OtherInfo		VARCHAR(2000)
												) AS tbl
	EXEC sp_xml_removedocument @handle

    INSERT INTO dbo.SettlementLog(MatchID,SportType, ActionID, UserID, ResourceID, HomeValue, AwayValue, OtherInfo) 
	SELECT	@MatchID		
		,	@SportType
		,	@ActionID				
		,	@AdminID 					
		,	ResourceID				
		,	HomeValue				
		,	AwayValue			
		,	OtherInfo
	FROM @tmpResourcesWeb


END
GO