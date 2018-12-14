/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Match_UpdateSaveBet]
	@action 			VARCHAR(20),
	@matchid 			INT,
	@SelectedSet 		VARCHAR(50)=NULL,
	@SelectedQuarter 	VARCHAR(50) = NULL,
	@IsFinalRound       BIT        = NULL
AS
/*
	Created: Kathy
	Date 20140213
	Task : Update SaveBet info (when run settlement)
	DB: DBACC/bodb02
	Original: Admin_Match_UpdateSaveBet

	Revisions:
		- 20141022@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
*/
BEGIN
	SET NOCOUNT ON
	IF @action = 'UNDO' AND ((@SelectedSet IS NULL OR @SelectedSet LIKE'%6%')
	                           OR ISNULL(@SelectedQuarter,'') LIKE '%FT%'
	                           OR ISNULL(@IsFinalRound,0) = 1
	                           )
	BEGIN
		-- RESET 'SaveBet' of DB06
		DELETE FROM Save_Jobs WHERE matchid = @matchid
		UPDATE Save_ListMatch SET IsGameFinish = 1 WHERE matchid = @matchid

		INSERT INTO Save_Jobs (matchid, liveindicator, savetype, bettype, typename)
		SELECT @matchid, 1, 'DEL', 0, 0
	END
END

GO
