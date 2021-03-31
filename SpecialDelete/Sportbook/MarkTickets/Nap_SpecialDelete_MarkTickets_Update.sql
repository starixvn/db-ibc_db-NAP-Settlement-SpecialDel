
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_MarkTickets_Update] @Status          SMALLINT      = 0,
                                                             @TransIds        VARCHAR(MAX)  = NULL,
                                                             @UserId          INT           = 0,
                                                             @Username        NVARCHAR(100) = '',
                                                             @IP              VARCHAR(15)   = NULL,                        
                                                             @ErrMsg          NVARCHAR(200) = '' OUTPUT,
                                                             @ErrCode         INT           = 0 OUTPUT
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

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	[108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20200730@Max: [TVS] Enhance Block Match of Unmark Ticket  [Redmine: #136734]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
*/
BEGIN
	SET NOCOUNT ON;

	-- Not Marked:
	IF @Status = 0
	BEGIN
		EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_Update] @TransIds = @TransIds
			,@UserId = @UserId
			,@Username = @Username
			,@IP = @IP
			,@ErrMsg = @ErrMsg OUTPUT
			,@ErrCode = @ErrCode OUTPUT;
	END
	-- Marked;
	ELSE
	BEGIN
		EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] @TransIds = @TransIds
			,@UserId = @UserId
			,@Username = @Username
			,@IP = @IP
			,@ErrMsg = @ErrMsg OUTPUT
			,@ErrCode = @ErrCode OUTPUT;
	END;

	SET NOCOUNT OFF;
END