/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_MarkTickets_Update] 
	   @Status          SMALLINT      = 0,
       @TransIds        VARCHAR(MAX)  = NULL,
       @UserId          INT           = 0,
       @IP              VARCHAR(15)   = NULL,   
	   @LogActionId     INT			  = 90500,
	   @IssueTypeId	    INT			  = NULL
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		- @Status: 
			+ 0: Not Marked
			+ 1: Marked
		- @LogActionId:
			+ 90500: SD - Action Mark 
			+ 90508: TVS - Mark by add request & Add mark when edit request
			+ 90501: SD - Action Unmark
		    + 90511: TVS - Unmark by edit request
			+ 90510: Unmark by autovoid System 

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	[108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20200730@Max: [TVS] Enhance Block Match of Unmark Ticket  [Redmine: #136734]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
*/
BEGIN
	SET NOCOUNT ON;

	-- Not Marked:
	IF @Status = 0
	BEGIN
		EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_Update] 
			@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@IssueTypeId = @IssueTypeId
			,@LogActionId = @LogActionId
	END
	-- Marked;
	ELSE
	BEGIN
		EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] 
			 @TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@LogActionId = @LogActionId
	END;

	SET NOCOUNT OFF;
END