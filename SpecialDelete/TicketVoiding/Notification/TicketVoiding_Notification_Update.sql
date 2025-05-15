/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Notification_Update](
      @IdList			VARCHAR(MAX) = NULL --'1,2,3' for case 'Mark all as read'
    , @RequestId		INT = NULL
    , @Content			NVARCHAR(MAX) = NULL
    , @Type				VARCHAR(50) = 'N'
    , @Username		    VARCHAR(50) = NULL
    , @IsRead			BIT = 0
)AS
/*	Created by: 20250415@July
    Task: [TVS] Notification [Redmine:#219112]
    DB: DBCTG-bodb02
    
    Revisions: 
        - 20250415@July: Create new SP [Redmine:#219112]

    Param's explanation:		
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @TargetUser NVARCHAR(MAX) = ''
          , @Id INT = 0
          , @UserId INT

    DECLARE @tmpIdList TABLE (Id INT, TargetUser NVARCHAR(MAX), IsFinish BIT)
    DECLARE @tmpTargetUser TABLE (Username NVARCHAR(50), IsRead NVARCHAR(1))

    IF ISNULL(@IdList, '') = ''
    BEGIN
        
        IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_Notification WITH (NOLOCK) WHERE RequestId = @RequestId)
        BEGIN
            SELECT TOP(1) @TargetUser = TargetUser
            FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
            WHERE RequestId = @RequestId
            ORDER BY CreatedDate DESC

            INSERT INTO @tmpTargetUser (Username, IsRead)
            SELECT Username, CAST (@IsRead AS VARCHAR(1)) --'0'
            FROM OPENJSON(@TargetUser)
            WITH (
                Username NVARCHAR(50)
            )

            IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WITH (NOLOCK) WHERE RequestId = @RequestId) --Have void/recover get username from history
            BEGIN
                
                SELECT TOP(1) @UserId = UserId
                FROM dbo.TicketVoiding_VoidingHistory WITH (NOLOCK)
                WHERE RequestId = @RequestId
                ORDER BY CreatedDate DESC

                INSERT INTO @tmpTargetUser (Username, IsRead)
                SELECT Username, CAST (@IsRead AS VARCHAR(1)) --'0'
                FROM CustDB.dbo.Customer WITH (NOLOCK)
                WHERE custid = @UserId
                    AND Username NOT IN (SELECT Username FROM @tmpTargetUser)
            END
		END
        
        IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpTargetUser WHERE Username = @Username)
		BEGIN
			INSERT INTO @tmpTargetUser (Username, IsRead)
            SELECT @Username, CAST (@IsRead AS VARCHAR(1)) --'0'
		END

        SET @TargetUser = CONVERT(NVARCHAR(MAX),
								(SELECT Username, IsRead
								FROM @tmpTargetUser
								FOR JSON PATH),1)

        INSERT INTO dbo.TicketVoiding_Notification (RequestId, TargetUser, [Type])
        SELECT @RequestId
             , @TargetUser
             , @Type

        SET @Id = SCOPE_IDENTITY()
        
        INSERT INTO @tmpIdList (Id) SELECT @Id

        
        IF CHARINDEX('@total', @Content) > 0
        BEGIN
            DECLARE @cnt_total INT = 0

            SELECT @cnt_total = COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
            WHERE RequestId = @RequestId

            SELECT @cnt_total += COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
            WHERE RequestId = @RequestId

            SET @Content = REPLACE(@Content, '@total', CAST (@cnt_total AS VARCHAR(10))) 
            
        END

        IF CHARINDEX('@marked', @Content) > 0
        BEGIN
            DECLARE @cnt_marked INT = 0
            
            WAITFOR DELAY '00:00:03' -- Delay 3 second to data marked sync with central DB

            SELECT @cnt_marked = COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
                INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON s.TransId = m.TransId
            WHERE RequestId = @RequestId

			IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK) WHERE RequestId = @RequestId)
			BEGIN
				SELECT  @cnt_marked += COUNT(1)
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON s.TransId = bm.TransId
					CROSS APPLY (
						 SELECT TOP 1 m.TransId 
						 FROM dbo.MarkedTransaction m WITH (NOLOCK) 
						 WHERE  s.MainTransId = m.TransId AND bm.matchid = m.MatchId -- Case main parlay for 2 match sub
					 )m
				WHERE RequestId = @RequestId
			END

            SET @Content = REPLACE(@Content, '@marked', CAST (@cnt_marked AS VARCHAR(10))) 
            
        END
        
        UPDATE dbo.TicketVoiding_Notification WITH (UPDLOCK, ROWLOCK)
        SET Content = @Content
        WHERE Id = @Id
	
    END
    ELSE 
    BEGIN
        
        INSERT INTO @tmpIdList (Id) 
        SELECT CAST(value AS INT) FROM STRING_SPLIT(@IdList, ',') WHERE value <> ''

        UPDATE t
        SET TargetUser = n.TargetUser
        FROM @tmpIdList t
            INNER JOIN dbo.TicketVoiding_Notification n WITH (NOLOCK) ON t.Id = n.Id

        WHILE (1=1) 
        BEGIN
            DELETE FROM @tmpTargetUser

            UPDATE TOP (1) t
            SET @Id = Id, @TargetUser = TargetUser, IsFinish = 1
            FROM @tmpIdList t
            WHERE isFinish IS NULL

            IF @@ROWCOUNT = 0 BREAK

            INSERT INTO @tmpTargetUser (Username, IsRead)
            SELECT Username, IsRead
            FROM OPENJSON(@TargetUser)
            WITH (
                Username NVARCHAR(50),
                IsRead NVARCHAR(1)
            );

            IF EXISTS (SELECT TOP 1 1 FROM @tmpTargetUser WHERE Username = @Username)
		    BEGIN
                UPDATE @tmpTargetUser
                SET IsRead = CAST (@IsRead AS VARCHAR(1)) --'1'
                WHERE Username = @Username 
            END

            SET @TargetUser = CONVERT(NVARCHAR(MAX),
								(SELECT Username, IsRead
								FROM @tmpTargetUser
								FOR JSON PATH),1)

            UPDATE dbo.TicketVoiding_Notification WITH (UPDLOCK, ROWLOCK)
            SET TargetUser = @TargetUser, ModifiedDate = GETDATE()
            WHERE Id = @Id 
        END

    END

	/************************************************************/
	/* 	- Get notification id affect*/
	SELECT Id, RequestId, Content, TargetUser, [Type], CreatedDate, ModifiedDate
	FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
	WHERE Id IN (SELECT Id FROM @tmpIdList)
    ORDER BY CreatedDate DESC

	/* 	- Get the list of users who have read the notification */
    SELECT DISTINCT a.UserName AS TargetUsername
    FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
        CROSS APPLY ( 
            SELECT Username
            FROM OPENJSON (CAST(TargetUser AS NVARCHAR(MAX)))
            WITH (
                  Username VARCHAR(50),
                  IsRead BIT
                )
        )a
    WHERE (RequestId = @RequestId OR a.Username = @Username)

END
GO