CREATE PROCEDURE [dbo].[Bet_ExecRep_05] 
	@IgnoreList 	VARCHAR(200)
	,@updatetype 	TINYINT = 1  -- 1, 2, 3, 4, 5
	,@_sXML 		VARCHAR(MAX)

AS
/*
	Created by:[Viet]
	Date:[26 Nov 2012]
	Task: for calculate tickets using replication for bet
	DB: all servers
	
	Revisions:
		- 20130131@Dan:		add virtual racing
		- 20131208@Viet:	add refund NG
		- 20140910@Kathy:	Include range of NG bettypes ( 81-> 120)
		- 20170614@Bobby: 77721 - Implement parlay bettype for BetRadar VS
		
	Param: 
		+ @updatetype: 
			+ 1: update bettrans: transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, moddds
			+ 2: update bettransm for virtual racing
			+ 3: update bettrans for virtual racing
			+ 4: refund number game
			+ 5: cal/refund VS BetRadar parlay
					
*/
BEGIN
	SET NOCOUNT ON
	IF EXISTS (SELECT TOP 1 1 from dbo.strSplit(ISNULL(@IgnoreList,''), ',') WHERE val = @@SERVERNAME) RETURN

	declare @_xml XML
	select @_xml = CONVERT(XML, @_sXML)

	IF @updatetype = 1 
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@f', 'money'), 0) as modds
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid
			,modds = s.modds
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103) THEN 1
				ELSE 0 END			
		FROM sourceData s
		WHERE bettrans.transid = s.transid
	END		
	ELSE IF @updatetype = 2 --bettransm (for virtual racing) 
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@h1', 'money'), 0) as hdp1
				,ISNULL(T.C.value('./@h2', 'money'), 0) as hdp2
				,ISNULL(T.C.value('./@l1', 'smallint'), 0) as livehomescore
				,ISNULL(T.C.value('./@l2', 'smallint'), 0) as liveawayscore
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid			
			,hdp1 = s.hdp1
			,hdp2 = s.hdp2
			,livehomescore = s.livehomescore
			,liveawayscore = s.liveawayscore
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103) THEN 1
				ELSE 0 END			
		FROM sourceData s
		WHERE bettransm.transid = s.transid
	END		
	ELSE IF @updatetype = 3 --bettrans (for virtual racing) 
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@f', 'money'), 0) as modds				
				,ISNULL(T.C.value('./@h1', 'money'), 0) as hdp1
				,ISNULL(T.C.value('./@h2', 'money'), 0) as hdp2
				,ISNULL(T.C.value('./@l1', 'smallint'), 0) as livehomescore
				,ISNULL(T.C.value('./@l2', 'smallint'), 0) as liveawayscore
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid
			,modds = s.modds			
			,hdp1 = s.hdp1
			,hdp2 = s.hdp2
			,livehomescore = s.livehomescore
			,liveawayscore = s.liveawayscore
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid in (111,112,113,103) THEN 1
				ELSE 0 END			
		FROM sourceData s
		WHERE bettrans.transid = s.transid
	END		
	ELSE IF @updatetype = 4 --refund number game
	BEGIN		
		DECLARE @matchid INT, @action varchar(10)

		SELECT @matchid = T.C.value('./@matchid', 'int')-- as matchid
			,@action = ISNULL(T.C.value('./@action', 'varchar(10)'), 0)-- as [action]
		from @_xml.nodes('/root/r') as [T](C) --T: table, C: column

		IF @action = 'Refund-FT'
		BEGIN
			UPDATE dbo.bettrans WITH (ROWLOCK,UPDLOCK)
			SET WinLost = actual_stake
				,aWinLost = 0
				,mWinLost = 0
				,sWinLost = 0
				,PlayerComm = 0
				,Comm = 0
				,aComm = 0
				,sComm = 0
				,[Status] = N'Refund'
				,StatusID = 103
				,ruben = 1
			WHERE matchid = @matchid 
				AND statusID IN (0, 1) -- only refund all running/waiting's tickets
				AND bettype BETWEEN 81 AND 120
		END
		ELSE
		BEGIN
			UPDATE dbo.bettrans WITH (ROWLOCK,UPDLOCK)
			SET WinLost = actual_stake
				,aWinLost = 0
				,mWinLost = 0
				,sWinLost = 0
				,PlayerComm = 0
				,Comm = 0
				,aComm = 0
				,sComm = 0
				,[Status] = N'Refund'
				,StatusID = 103
				,ruben = 1
			WHERE matchid = @matchid 
				AND statusID NOT IN (101,102) -- refund all, except void/reject
				AND bettype BETWEEN 81 AND 120
		END		
	END
	ELSE IF @updatetype = 5 --CAL/REFUND VS BetRadar parlay
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@t', 'int') as transid
				,T.C.value('./@d', 'DATE') as winlostdate
				,T.C.value('./@w', 'TINYINT') as statuswinlost
				,T.C.value('./@s', 'TINYINT') as statusId				
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
		SET winlostdate		= s.winlostdate
			,statuswinlost	= s.statuswinlost
			,statusId		= s.statusId
			,status			= CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103) THEN 1
				ELSE 0 END			
		FROM sourceData s
		WHERE bettransm.transid = s.transid
	END
END
GO

