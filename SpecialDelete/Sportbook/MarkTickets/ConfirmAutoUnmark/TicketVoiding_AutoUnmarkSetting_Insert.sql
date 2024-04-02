/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoUnmarkSetting_Insert]
(
	@Matchid		 INT,
	@Bettype		 SMALLINT,
	@MarkedBy		 INT,
	@Betid			 BIGINT = NULL,
	@UserId          INT = 0
)
AS
/*	Created by: July
	Date 20220831
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220831@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	--Step 1: Insert table TicketVoiding_AutoUnmarkSetting
	INSERT INTO dbo.TicketVoiding_AutoUnmarkSetting (Matchid, Bettype, IsConfirm, CreatedDate, UserId, MarkedBy, betid)
	VALUES(@Matchid, @Bettype, 1, GETDATE(), @UserId, @MarkedBy, @Betid)
	
END