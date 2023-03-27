/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_WriteLog_IntervalResult]
	@SportType			SMALLINT
	,@MatchId			INT
	,@StateId			TINYINT
	,@SelectedResources	VARCHAR(MAX)
	,@BroadcastSessionId VARCHAR(50)
AS
/*
	Created: 20230210@Kathy
	Task: write log for interval result [Redmine:#182007]
	DB: DBLOG/bodb_CustomerLog

	Revisions: 
		- 20230210@Kathy: Add interval results into log [Redmine:#182007]

	Param's Explanation:
	* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" AffectedTicket="1"/>
									<Resource Id="M2" Home="2" Away="4" AffectedTicket="12"/>
							   </Resources>'
	 @StateId: 1 - pushed in queue
			   2 - settled
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlSelectedResouces XML
	DECLARE @tmpSelectedResources TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), AffectedTicket INT)

	SET @xmlSelectedResouces = CAST(@SelectedResources AS XML)
			
	INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, AffectedTicket)
	SELECT	T.C.value('@Id','VARCHAR(20)') 
			,T.C.value('@Home','VARCHAR(2000)') 
			,T.C.value('@Away','VARCHAR(2000)') 
			,T.C.value('@AffectedTicket','INT') 
	FROM	@xmlSelectedResouces.nodes('/Resources/Resource') AS T(C)	

	INSERT INTO dbo.Userlog_Settle_IntervalResult (Sporttype, MatchId, ResourceId, HomeValue, AwayValue, AffectedTicket, LogDate, StateId, BroadcastSessionId)
	SELECT	@SportType, @MatchId, ResourceID, HomeValue, AwayValue, AffectedTicket, GETDATE(), @StateId, @BroadcastSessionId
	FROM	@tmpSelectedResources

END
GO
