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
    DECLARE @tmpIdList TABLE (Id INT, IsFinish BIT)
  
    IF @IdList IS NULL 
    BEGIN
        
        IF CHARINDEX('@marked', @Content) > 0 AND CHARINDEX('@total', @Content) > 0
        BEGIN
            DECLARE @cnt_marked INT = 0, @cnt_total INT = 0
            
            -- Check if the request is a single ticket or a parlay ticket
            SELECT @cnt_marked = COUNT(CASE WHEN m.TransId IS NOT NULL THEN 1 END)
                  ,@cnt_total = COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
                LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON s.TransId = m.TransId
            WHERE RequestId = @RequestId

            SELECT  @cnt_marked += COUNT(CASE WHEN m.TransId IS NOT NULL THEN 1 END)
                    ,@cnt_total += COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
                LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON s.TransId = m.TransId
            WHERE RequestId = @RequestId

            SET @Content = REPLACE(@Content, '@marked', CAST (@cnt_marked AS VARCHAR(10)))
            SET @Content = REPLACE(@Content, '@total', CAST (@cnt_total AS VARCHAR(10)))

        END
        
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
					WHERE Username = @Username AND IsRead = @IsRead)
			BEGIN
				SET @TargetUser = REPLACE(@TargetUser, ']', ',{"Username":"'+ @Username +'","IsRead":"'+ CAST (@IsRead AS VARCHAR(1)) +'"}]')
			END
		END
		ELSE
		BEGIN
			SET @TargetUser = '[{"Username":"'+ @Username +'","IsRead":"'+ CAST (@IsRead AS VARCHAR(1)) +'"}]'
		END

        INSERT INTO dbo.TicketVoiding_Notification (RequestId, Content, TargetUser, [Type])
        SELECT @RequestId
             , @Content
             , @TargetUser
             , @Type

        INSERT INTO @tmpIdList (Id)
		SELECT SCOPE_IDENTITY()
	END
    ELSE 
    BEGIN
        DECLARE @Id INT = 0
        
        INSERT INTO @tmpIdList (Id) 
        SELECT CAST(value AS INT) FROM STRING_SPLIT(@IdList, ',') WHERE value <> ''

        WHILE (1=1) 
        BEGIN
            UPDATE TOP (1) t
            SET @Id = Id, IsFinish = 1
            FROM @tmpIdList t
            WHERE isFinish IS NULL

            IF @@ROWCOUNT = 0 BREAK

            SELECT TOP(1) @TargetUser = TargetUser
            FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
            WHERE Id = @Id

            DECLARE @target NVARCHAR(100) = '{"Username":"' + @Username + '","IsRead":"';

            DECLARE @pos INT = CHARINDEX(@target, @TargetUser);

            IF @pos > 0
            BEGIN
                DECLARE @valueStart INT = @pos + LEN(@target); 
                
                SET @TargetUser = STUFF(@TargetUser, @valueStart, 1, CAST (@IsRead AS VARCHAR(1))); 

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