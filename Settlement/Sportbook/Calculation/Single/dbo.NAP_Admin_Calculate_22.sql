/****** Object:  StoredProcedure [dbo].[NAP_Admin_Calculate_22]    Script Date: 08/27/2014 13:59:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Admin_Calculate_22    Script Date: 2/26/2014 6:01:44 PM ******/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_22] @matchid INT
	,@bettype SMALLINT
	,@ResultString NVARCHAR(50)
	,@betcount INT = 0
AS
/*
Created: Kathy
Date: 20140211
Task : Settlement for Next Goal Bettype  

Revisions:
    - 20151209@Patrick: Database - Change datatype [Redmine: #48660]

Param's Explanation:
• @ResultString: + get from match.GoalRecord,
                 + uses nvarchar to avoid problem compare with varchar from betteam

*/
BEGIN
	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

	SET NOCOUNT ON

	----- LAS settlement 
	--IF @@SERVERNAME IN ('DB052', 'DB054', 'DB231', 'DB232') AND EXISTS (
	--		SELECT *
	--		FROM sys.databases
	--		WHERE NAME = 'LASDB'
	--		)
	--BEGIN
	--	DECLARE @LASCommand NVARCHAR(1000)
	--		,@createdDate DATETIME

	--	SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_22] @matchid = ' + CONVERT(NVARCHAR(20), @matchid) + ', @bettype = ' + CONVERT(NVARCHAR(10), @bettype) + ', @ResultString = ''' + CONVERT(NVARCHAR(50), @ResultString) + '''' + ', @betcount = ' + CONVERT(NVARCHAR(10), ISNULL(@betcount, ''))
	--		,@createdDate = GETDATE()

	--	EXEC LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_22'
	--		,@SQLCommand = @LASCommand
	--		,@CreatedDate = @createdDate
	--		,@StatusID = 0 -- waiting
	--		,@MatchID = @matchid
	--		,@Bettype = @bettype
	--		,@Status = 'waiting'
	--		,@BetCount = @betcount
	--END

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
	DECLARE @hdp SMALLMONEY

	UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
	SET @hdp = CASE betteam
			WHEN N'h' THEN hdp2 - hdp1
			WHEN N'a' THEN hdp1 - hdp2
			END
		,@modds = CASE SUBSTRING(@ResultString, livehomescore + liveawayscore + 1, 1)
			WHEN N'' THEN @hdp
			WHEN betteam THEN 1 + @hdp
			ELSE - 1 + @hdp
			END
		,modds = @modds
		,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0
			ELSE 1
			END
		,@commLostRate = CASE comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2
			ELSE 1
			END
		,--'s','m'
		WinLost = CASE 
			WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					)
			WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * 0.5
			WHEN @modds = 0 THEN actual_stake
			WHEN @modds = - 0.25 THEN actual_stake * 0.5
			WHEN @modds < - 0.25 THEN 0
			END
		,aWinLost = CASE 
			WHEN @modds > 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - apositiontaking
			WHEN @modds = 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - apositiontaking * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
			WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
			END
		,mWinLost = CASE 
			WHEN @modds > 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - mpositiontaking
			WHEN @modds = 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - mpositiontaking * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
			WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
			END
		,sWinLost = CASE 
			WHEN @modds > 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - spositiontaking
			WHEN @modds = 0.25 THEN stake * (CASE 
					WHEN odds < 0 THEN 1
					ELSE (CASE 
							WHEN bettype IN (4, 5, 6) THEN odds - 1
							ELSE odds END
							) END
					) * - spositiontaking * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
			WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
			END
		,PlayerComm = CASE 
			WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
			WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
			WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
			END
		,Comm = CASE 
			WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
			WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
			WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
			END
		,aComm = CASE 
			WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
			WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
			WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
			END
		,sComm = CASE 
			WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
			WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
			WHEN @modds = 0 THEN 0
			WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
			WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
			END
		,STATUS = CASE 
			WHEN @modds > 0 THEN N'WON'
			WHEN @modds = 0 THEN N'DRAW'
			WHEN @modds < 0 THEN N'LOSE'
			END
		,StatusID = CASE 
			WHEN @modds > 0 THEN 112 --WON
			WHEN @modds = 0 THEN 111 --DRAW
			WHEN @modds < 0 THEN 113 --LOSE
			END
		,ruben = 1
	WHERE matchid = @matchid AND bettype = @bettype AND
		--[status] NOT IN (N'VOID', N'REJECT')
		statusID NOT IN (101, 102)
END

GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_22] TO [vnteam] AS [dbo]