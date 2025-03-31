/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckExistingRequest]
(	
	 @TransInfoJson VARBINARY(MAX) = NULL
	,@RequestId	INT = 0
)
AS
/*	
	Created by: 20250311@Max
	Task: [TVS] Enhance the Auto Void flow (Instant with Policy) of Abnormal Account  [#Redmine: #217979]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250311@Max: Init SP [#Redmine: #217979]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX)
	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

	DECLARE  @tmpTrans AS TABLE(
	   matchid			INT
	  ,transid			BIGINT      
	  ,statusID			TINYINT
	)

	INSERT INTO @tmpTrans( 
		   matchid, transid, statusID
		)
	SELECT mid ,t ,sid 
	FROM  OPENJSON(@Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, sid TINYINT)

	SELECT DISTINCT t.transid
	FROM @tmpTrans t
		CROSS APPLY (
				SELECT rs.RequestId
				FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) 
				WHERE rs.MatchId = t.matchid AND rs.TransId = t.transid
			) rs
		CROSS APPLY (
			SELECT TOP 1 1 AS IsValid
			FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
			WHERE r.RequestId = rs.RequestId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2) 
				AND r.IssueTypeId NOT IN (22)
				AND 1 = CASE WHEN r.IssueTypeId = 11 AND t.StatusId NOT IN (111,112,113) THEN 1
					WHEN r.IssueTypeId <> 11 THEN 1
					ELSE 0 END 
		)r

END
GO

