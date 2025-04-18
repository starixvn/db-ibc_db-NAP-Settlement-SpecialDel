/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Notification_Update](
	  @RequestId		INT 
	, @Content			VARCHAR(MAX) = NULL
	, @TargetUser		VARCHAR(MAX) = NULL
	, @Type				VARCHAR(50) = NULL
	, @IsUpdate			BIT = 0
	, @Id				INT = NULL
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
	
	IF @IsUpdate = 0 
	BEGIN
		INSERT INTO dbo.TicketVoiding_Notification (RequestId, Content, TargetUser, [Type])
		SELECT @RequestId, @Content, @TargetUser, @Type
	END
	ELSE 
	BEGIN
		UPDATE dbo.TicketVoiding_Notification WITH (UPDLOCK, ROWLOCK)
		SET Content = @Content, TargetUser = @TargetUser
		WHERE RequestId = @RequestId 
			AND Id = @Id	
	END

	SELECT DISTINCT TargetUserName
	FROM dbo.TicketVoiding_Notification WITH (NOLOCK)
		CROSS APPLY ( 
			SELECT Username AS TargetUserName
			FROM OPENJSON (CAST(TargetUser AS NVARCHAR(MAX)))
			WITH (
				  Username VARCHAR(100),
				  IsRead BIT
				)
		)a
	WHERE RequestId = @RequestId
END
GO