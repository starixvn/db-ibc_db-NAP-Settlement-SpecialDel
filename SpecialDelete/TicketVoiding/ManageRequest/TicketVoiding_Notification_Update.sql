/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Notification_Update](
      @Id				INT = NULL
    , @RequestId		INT = NULL
    , @Content			VARCHAR(MAX) = NULL
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
    
    IF @Id IS NULL 
    BEGIN
        
        IF CHARINDEX('@@', @Content) > 0
        BEGIN
            DECLARE @cnt INT = 0
            
            -- Check if the request is a single ticket or a parlay ticket
            SELECT @cnt = COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
            WHERE RequestId = @RequestId

            SELECT @cnt = @cnt + COUNT(1)
            FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
            WHERE RequestId = @RequestId

            SET @Content = REPLACE(@Content, '@@', CAST (@cnt AS VARCHAR(10)))

        END
        
        IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_Notification WITH (NOLOCK) WHERE RequestId = @RequestId)
        BEGIN
            
            SELECT TOP(1) @TargetUser = TargetUser
            FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
            WHERE RequestId = @RequestId
            ORDER BY CreatedDate DESC

			 IF NOT EXISTS (SELECT 1
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

		SET @Id = SCOPE_IDENTITY()
	END
    ELSE 
    BEGIN
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

	/************************************************************/
	/* 	- Get notification id affect*/
	SELECT Id, RequestId, Content, TargetUser, [Type], CreatedDate, ModifiedDate
	FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
		WHERE Id = @Id

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