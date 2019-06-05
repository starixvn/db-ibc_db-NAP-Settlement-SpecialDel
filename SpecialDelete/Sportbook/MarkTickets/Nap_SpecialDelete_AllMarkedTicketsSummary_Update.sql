
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Update] @Matches  XML           = NULL,
                                                                         @UserId   INT           = 0,
                                                                         @Username NVARCHAR(100) = N'',
                                                                         @IP       VARCHAR(15)   = NULL,
                                                                         @ErrMsg   NVARCHAR(200) = '' OUTPUT,
                                                                         @ErrCode  INT           = 0 OUTPUT
AS

/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		
	Explanation's Param:
	@Matches: <Matches><Match MatchId="1" UserId="1" CreatedDate="2019-03-04 04:11:33.240"/></Matches>
*/


     SET NOCOUNT ON;
     CREATE TABLE #Match
                  (MatchId     INT,
                   UserId      INT,
                   CreatedDate DATETIME
                  );
     INSERT INTO #Match
            (MatchId,
             UserId,
             CreatedDate
            )
            SELECT x.value('@MatchId', 'INT') AS MatchId,
                   x.value('@UserId', 'INT') AS UserId,
                   x.value('@CreatedDate', 'DATETIME') AS CreatedDate
            FROM @Matches.nodes('Matches/Match') XmlData(x) OPTION(OPTIMIZE FOR(@Matches = NULL));
    

-- Delete Transaction
     WHILE(0 = 0)
         BEGIN
             DELETE TOP (2000)
             m
             FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
                  INNER JOIN #Match t ON t.MatchId = m.MatchId
                                         AND t.UserId = m.UserId
                                         AND m.CreatedDate = t.CreatedDate;
             IF @@ROWCOUNT = 0
                 BREAK;
         END; 

-- Insert Settled_Message
     INSERT INTO [dbo].[Settled_Message]
            ([AdminId],
             [MatchId],
             [IP],
             [Starttime],
             [Action],
             [Message],
             [IsRead],
             [Warning],
             [IsSent]
            )
            SELECT 111,
                   t.matchid,
                   @IP,
                   GETDATE(),
                   'UNMARK',
                   'has all tickets unmarked by '+@Username,
                   0,
                   NULL,
                   0
            FROM #Match t 
                LEFT JOIN
				(
				    SELECT m.matchid
				    FROM dbo.MarkedTransaction m WITH (NOLOCK)
					    INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = m.TransId
														  AND b.statusID IN(0, 1)
				) mt ON mt.MatchId = t.MatchId
            WHERE mt.MatchId IS NULL;
     SELECT b.MatchId,
            m.HomeId,
            m.AwayId,
            m.SportType,
            m.IsNeutral
     FROM #Match b
          INNER JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;
-- Write Log
     DECLARE @LogActionId INT= 90501, @LogData VARCHAR(MAX);
     SET @LogData = CAST(
(
    SELECT @LogActionId AS '@LogActionId',
           @UserId AS '@UserId',
           @IP AS '@IP',
           'Status: 1, Matches: '+CAST(@Matches AS VARCHAR(MAX)) AS '@LogData' FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX));
     EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage
          @xml = @LogData,
          @functionName = 'TicketVoiding',
          @MessageType = 'MessageType_TicketVoiding_Log';
     DROP TABLE #Match;
     SET NOCOUNT OFF;
GO