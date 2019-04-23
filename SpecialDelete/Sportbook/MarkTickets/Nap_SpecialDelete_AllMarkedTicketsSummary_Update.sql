
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Update] @MatchIds VARCHAR(MAX)  = NULL,
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
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion
		
	Explanation's Param:
*/


     SET NOCOUNT ON;
     CREATE TABLE #Match
                  (MatchId INT
                   PRIMARY KEY
                  );
     INSERT INTO #Match(MatchId)
            SELECT DISTINCT
                   val
            FROM dbo.f_SplitString(@MatchIds, ',')
            WHERE val <> '' OPTION(MAXRECURSION 0);

-- Delete Transaction
	WHILE (0=0)
	BEGIN
		DELETE TOP (2000) m 
		FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
			  INNER JOIN #Match t ON t.MatchId = m.MatchId;
		IF @@ROWCOUNT = 0 BREAK	  
	END 

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
            FROM #Match t;

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
			    'Status: 1, MatchIds: '+@MatchIds AS '@LogData' FOR XML PATH('r'), ROOT('root'), TYPE
	   ) AS VARCHAR(MAX));
     EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage
          @xml = @LogData,
          @functionName = 'TicketVoiding',
          @MessageType = 'MessageType_TicketVoiding_Log';
     DROP TABLE #Match;
     SET NOCOUNT OFF;
GO