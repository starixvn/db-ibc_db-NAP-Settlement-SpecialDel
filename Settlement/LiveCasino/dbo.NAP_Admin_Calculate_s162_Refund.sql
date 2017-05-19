/****** Object:  StoredProcedure [dbo].[NAP_Admin_Calculate_s162_Refund]    Script Date: 09/10/2014 09:12:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_s162_Refund]
	@matchid int	
AS
/*
	Created by: Kathy
	Date: 20140224
	Task: Settlement (Refund)
	DB: DBO2.BODB02
	Original Admin_Calculate_s162_Refund
	Revisions:		
		- 20140910@Kathy: Include range of LC bettypes (1101 -> 1199)
*/
SET NOCOUNT ON

IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044')
BEGIN
	UPDATE dbo.bettransG WITH(ROWLOCK, UPDLOCK)
	SET  
		WinLost = stake ,
		statuswinlost=0,
		aWinLost = 0,
		mWinLost = 0,
		sWinLost = 0,
		PlayerComm = 0,
		Comm = 0,
		aComm = 0,
		sComm = 0,
		[Status] = N'Refund',
		StatusID = 103,
		ruben=1
	WHERE matchid=@matchid
		AND statusID NOT IN (101,102) -- void, reject
END

IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044')
BEGIN
	UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
	SET  
		WinLost = actual_stake,
		statuswinlost=0,
		aWinLost = 0,
		mWinLost = 0,
		sWinLost = 0,
		PlayerComm = 0,
		Comm = 0,
		aComm = 0,
		sComm = 0,
		[Status] = N'Refund',
		StatusID = 103,
		ruben=1
	WHERE matchid=@matchid
		and statusID NOT IN (101,102)
		AND bettype BETWEEN 1101 AND 1199
END



GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_s162_Refund] TO [vnteam] AS [dbo]