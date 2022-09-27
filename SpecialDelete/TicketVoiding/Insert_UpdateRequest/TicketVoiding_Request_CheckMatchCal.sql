/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Request_CheckMatchCal]
(
	@MatchId INT
)
AS
/*	
	Created by: July
	Date 20220923
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220923@July: Create new SP - Check match CAL [Redmine: #175412]

	Param's explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IsCalMatchId BIT

	SET @IsCalMatchId = ( SELECT TOP (1) 1
								FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
								WHERE StatusId IN (0,2) AND RequestId = 0
								AND MatchId = @MatchId
						)
	SELECT ISNULL(@IsCalMatchId,0) AS IsCalMatchId

END
GO