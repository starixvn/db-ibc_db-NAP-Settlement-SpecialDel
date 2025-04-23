/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Notification_Select](
	  @Username		VARCHAR(50) = NULL 
)AS
/*	Created by: 20250415@July
	Task: [TVS] Notification [Redmine:#219112]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20250415@July: Create new SP [Redmine:#219112]

	Param's explanation:	
		- Note table: TicketVoiding_Notification - Only support data within 14 days	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SettingTime DATETIME
	-- Set the time to 14 days before the current date
	SET @SettingTime = DATEADD(DAY, -14, GETDATE())

	DECLARE @IdList TABLE (Id INT, RequestId INT,Content NVARCHAR(MAX), TargetUsername NVARCHAR(MAX), IsRead BIT, [Type] VARCHAR(50), CreatedDate DATETIME)

	INSERT INTO @IdList (Id, RequestId, Content, TargetUsername, IsRead, [Type], CreatedDate)
	SELECT Id, n.RequestId, Content, a.Username AS TargetUsername, a.IsRead, [Type], CreatedDate
	FROM dbo.TicketVoiding_Notification n WITH (NOLOCK)
		CROSS APPLY ( 
			SELECT Username , IsRead
			FROM OPENJSON (CAST(TargetUser AS NVARCHAR(MAX)))
			WITH (
				  Username VARCHAR(50),
				  IsRead BIT
				)
		)a
	WHERE CreatedDate > @SettingTime
		AND Username = @Username

	SELECT Id, RequestId, Content, TargetUsername, IsRead, [Type], CreatedDate
	FROM @IdList
	WHERE Content NOT LIKE '%voided%' AND Content NOT LIKE '%recovered%'

	UNION ALL

	SELECT MIN(Id) AS Id, RequestId, Content, TargetUsername, IsRead, [Type], MIN(CreatedDate) AS CreatedDate
	FROM @IdList
	WHERE Content LIKE '%voided%' OR Content LIKE '%recovered%'
	GROUP BY RequestId, Content, TargetUsername, IsRead, [Type]
	
END
GO