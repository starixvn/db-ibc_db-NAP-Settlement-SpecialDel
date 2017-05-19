CREATE PROCEDURE [NAP_Set_MatchUpdPending]
	@matchid int,
	@IsPending bit,
	@userID int 
WITH RECOMPILE
/*	Created: Dan
	Task:  	
	DB: DB02.bodb02
	Original SP: [Admin_Match_Pending]
	
	Revisions:
	
	Param's Explanation: 
*/
AS
SET NOCOUNT ON 

DECLARE @dbisPending BIT, @dbIsHTCal BIT, @dbcalculate BIT

SELECT	@dbisPending = isPending, @dbIsHTCal = IsHTCal, @dbcalculate = calculate 
FROM	Match_remark WITH (NOLOCK) 
WHERE	matchid = @matchid 

EXEC NAP_updateMatch_remark @matchid, 'IsP', @IsPending

--write log
DECLARE @LogData NVARCHAR(200)
SELECT @LogData = 'Update Pending Match : ' + cast(@matchid as varchar(30)) + ' with IsPending = ' + cast(@IsPending as varchar(2)) 
				+ '. Old Value : IsPending = ' + cast(@dbisPending as varchar(2)) + ' - IsHTCal = ' + cast(@dbIsHTCal as varchar(2))+ ' - calculate = ' + cast(@dbcalculate as varchar(2))

EXEC WriteLog_UserLog @UserID = @UserID, @Doing = @LogData

GO

GRANT EXECUTE ON [NAP_Set_MatchUpdPending] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Set_MatchUpdPending] TO [vnteam] AS [dbo]
GO


