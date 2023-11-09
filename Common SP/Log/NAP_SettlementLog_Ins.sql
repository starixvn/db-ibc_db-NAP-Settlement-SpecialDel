/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementLog_Ins]
	@MatchID				INT				=	NULL,
	@SportType 				INT				=	NULL,
	@Action					VARCHAR(20)		=	NULL,
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
		
	Param's Explanation:
		-   @IsAuto = 1 When action from NAP_Admin_Settlement_Auto_1s_Push
*/
BEGIN
    SET NOCOUNT ON;
	DECLARE		@handle				INT,
				@ActionID			INT
	DECLARE		@tmpResourcesWeb	TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OtherInfo VARCHAR(2000))

	SELECT  @ActionID = CASE
						  WHEN @Action = 'CAL' AND @IsAuto =0		THEN 100
						  WHEN @Action = 'CAL' AND @IsAuto =1		THEN 148 
						  WHEN @Action = 'CAL-FT'					THEN 101
						  WHEN @Action = 'CAL-HT'					THEN 102
						  WHEN @Action = 'CAL_EAR'					THEN 189

						  WHEN @Action = 'UNDO' AND @IsAuto =0		THEN 103
						  WHEN @Action = 'UNDO'	AND @IsAuto =1		THEN 149 
						  WHEN @Action = 'UNDO_EAR'					THEN 190
						  WHEN @Action = 'UNDO-FT'					THEN 81040

						  WHEN @Action = 'REFUND' AND @IsAuto =0	THEN 109
						  WHEN @Action = 'REFUND' AND @IsAuto =1	THEN 150
						  WHEN @Action = 'REFUND_EAR'				THEN 191
						  WHEN @Action = 'REFUND-HT'				THEN 110
						  WHEN @Action = 'REFUND-FT'				THEN 111
						  WHEN @Action = 'REFUND-BetFair'			THEN 135
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