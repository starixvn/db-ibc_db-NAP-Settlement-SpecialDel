/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Request_AutoVoidQueue_Update]
(
	@RequestId				INT
   ,@IssueTypeId			TINYINT	= NULL
   ,@MatchInfo				VARCHAR(MAX) = NULL
   ,@ActionID				TINYINT = NULL
   ,@FilterBy				TINYINT = NULL
   ,@IsEditRequest			INT = 0
   ,@TransIds				VARCHAR(MAX) = NULL
   ,@BroadcastSessionId		VARCHAR(50)
)
AS
/*	
	Created by: July
	Date 20220808
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Insert auto void queue [Redmine: #175412]

	Param's explanation:
		+ @IssueTypeId : 11 - Abnormal Bet, 15 - AB(real member), 13 - Abnormal account
		+ @MatchInfo : <root><r matchid="1,2,3" sporttype =""/></root>
		+ @TransIds: apply for issuetype (11,15)
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchInfoXML		 XML = NULL
		   ,@IsCalQueue			 BIT = 0
		   ,@IsTransidProcessed  BIT = 0
		   ,@SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tmpMatchId (matchId INT, sporttype SMALLINT)
	CREATE TABLE #tmpTransId (transid BIGINT, statusid INT, statuswinlost TINYINT)

	SET @MatchInfoXML = CONVERT(XML, @MatchInfo)
	INSERT INTO #tmpMatchId (matchId, sporttype)
	SELECT t.c.value('@matchid','INT') AS matchId	
		  ,t.c.value('@sporttype','SMALLINT') AS sporttype
	FROM @MatchInfoXML.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@MatchInfoXML = NULL))

	IF @TransIds IS NOT NULL AND @ActionID = 1
	BEGIN
		INSERT INTO #tmpTransId (transid, statusid, statuswinlost)
		SELECT DISTINCT t.value, b.statusID, b.statuswinlost
		FROM dbo.bettrans b WITH (NOLOCK) 
			INNER JOIN STRING_SPLIT(@TransIds, ',') t ON b.TransId = CAST(t.value AS BIGINT)
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		SET @IsCalQueue = ( SELECT TOP (1) 1
									FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
									WHERE StatusId IN (1,2,4) AND RequestId = 0
									AND matchid IN ( SELECT MatchId FROM #tmpMatchId)
								)
		IF EXISTS (SELECT TOP (1) 1 FROM #tmpTransId WHERE statusid = 0 AND statuswinlost IS NOT NULL)
				SET @IsTransidProcessed = 1
	END

	IF @IssueTypeId = 13 
	BEGIN
		INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype, BroadcastSessionId)
		SELECT @RequestId, 0, 'VoidInstant', 99, 10278938, GETDATE(), '125.227.140.97', NULL, @BroadcastSessionId
	END
	ELSE IF @IssueTypeId IN (11,15)
	BEGIN
		-- Insert queue for auto void
		IF @ActionId IN (4,6,7,8) OR (@ActionID = 1 AND @FilterBy IS NULL AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype, BroadcastSessionId)
			SELECT @RequestId
					, matchid
					, CASE WHEN @ActionId = 1 THEN 'AddRequest' 
						   WHEN @ActionId = 4 THEN 'VoidInstant'
						   WHEN @ActionId = 6 THEN 'VoidInstant5m'
						   WHEN @ActionId = 7 THEN 'VoidInstant10m' 
						   WHEN @ActionId = 8 THEN 'VoidInstantNopolicy'
						ELSE '' END 
			      , 99, 10278938, GETDATE(), '125.227.140.97'
				  , sporttype
				  , @BroadcastSessionId
			FROM #tmpMatchId
		END
	END

	DROP TABLE #tmpTransId
	DROP TABLE #tmpMatchId
END
GO