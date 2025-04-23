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
          , @target NVARCHAR(100)
          , @pos INT
          , @valuestart INT
          , @Id INT = 0

    DECLARE @tmpIdList TABLE (Id INT, TargetUser NVARCHAR(MAX), IsFinish BIT)
  
    IF ISNULL(@IdList, '') = ''
    BEGIN
        
        IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_Notification WITH (NOLOCK) WHERE RequestId = @RequestId)
        BEGIN
            
            SELECT TOP(1) @TargetUser = TargetUser
            FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
            WHERE RequestId = @RequestId
            ORDER BY CreatedDate DESC

			 IF NOT EXISTS (SELECT TOP 1 1
					FROM OPENJSON(@TargetUser)
					WITH (
						Username VARCHAR(50),
				  		IsRead BIT) 
					WHERE Username = @Username)
			BEGIN
				SET @TargetUser = REPLACE(@TargetUser, ']', ',{"Username":"'+ @Username +'","IsRead":"'+ CAST (@IsRead AS VARCHAR(1)) +'"}]')
			END
            ELSE
            BEGIN       
                SET @target = '{"Username":"' + @Username + '","IsRead":"';

                SET @pos = CHARINDEX(@target, @TargetUser);

                IF @pos > 0
                BEGIN
                    SET @valuestart = @pos + LEN(@target); 
                
                    SET @TargetUser = STUFF(@TargetUser, @valuestart, 1, CAST (@IsRead AS VARCHAR(1))); 

                END
            END
		END
		ELSE
		BEGIN
			SET @TargetUser = '[{"Username":"'+ @Username +'","IsRead":"'+ CAST (@IsRead AS VARCHAR(1)) +'"}]'
		END

        INSERT INTO dbo.TicketVoiding_Notification (RequestId, TargetUser, [Type])
        SELECT @RequestId
             , @TargetUser
             , @Type

        SET @Id = SCOPE_IDENTITY()
        
        INSERT INTO @tmpIdList (Id) SELECT @Id

         IF CHARINDEX('@marked', @Content) > 0 AND CHARINDEX('@total', @Content) > 0
        BEGIN
            DECLARE @cnt_marked INT = 0, @cnt_total INT = 0
            
            WAITFOR DELAY '00:00:03' -- Delay 3 second to data marked sync with central DB

            SELECT @cnt_marked = SUM(CASE WHEN m.TransId IS NOT NULL THEN 1 ELSE 0 END)
                  ,@cnt_total = COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
                LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON s.TransId = m.TransId
            WHERE RequestId = @RequestId

            SELECT  @cnt_marked += SUM(CASE WHEN m.TransId IS NOT NULL THEN 1 ELSE 0 END)
                   ,@cnt_total += COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
                LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON s.TransId = m.TransId
            WHERE RequestId = @RequestId

            SET @Content = REPLACE(@Content, '@marked', CAST (@cnt_marked AS VARCHAR(10))) 
            SET @Content = REPLACE(@Content, '@total', CAST (@cnt_total AS VARCHAR(10)))
            
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
            UPDATE TOP (1) t
            SET @Id = Id, @TargetUser = TargetUser, IsFinish = 1
            FROM @tmpIdList t
            WHERE isFinish IS NULL

            IF @@ROWCOUNT = 0 BREAK

            SET @target = '{"Username":"' + @Username + '","IsRead":"';

            SET @pos = CHARINDEX(@target, @TargetUser);

            IF @pos > 0
            BEGIN
                SET @valuestart = @pos + LEN(@target); 
                
                SET @TargetUser = STUFF(@TargetUser, @valuestart, 1, CAST (@IsRead AS VARCHAR(1))); 

                UPDATE dbo.TicketVoiding_Notification WITH (UPDLOCK, ROWLOCK)
                SET TargetUser = @TargetUser, ModifiedDate = GETDATE()
                WHERE Id = @Id 
            END
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