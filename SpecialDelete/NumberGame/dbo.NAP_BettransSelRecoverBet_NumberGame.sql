/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelRecoverBet_NumberGame]
	@Option BIT = 0,
	@MatchId BIGINT = 0,
	@FromTransId BIGINT = 0,
	@ToTransId BIGINT = 0,

	@TransIds VARCHAR(4000) = '',
	@InvalidTransIds VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Kathy
	Date: 
	DB: DBTXN/bodb02

	Revisions: 
		- 20140210@Kathy: Correct winlost value
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20180528@Alan: Return MatchCode Column [Redmine:#95949 ]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20200811@Charles: Implement Next R/B bet type for NG Color Ball - [128215]

	Param's Explanation:
			- @Opition: 
			0: By MatchID
			1: By BetID(s)
*/
BEGIN
	SET NOCOUNT ON 
	DECLARE @tblRecoverNG TABLE (
	            transid BIGINT,
				custid int, 
				recommend INT, 
	            username VARCHAR(50),
	            transdate DATETIME,
	            odds MONEY,
	            stake MONEY,
	            winlost MONEY,
	            STATUS NVARCHAR(10),
	            CurrencyName VARCHAR(10),
	            bettype SMALLINT,
				matchid int,
				OddsType tinyint,
				betteam nvarchar(10),
				hdp1 smallmoney,
				hdp2 smallmoney,
				MatchCode NVARCHAR(50),
				leagueid int,
				IsLiveIndicator BIT,
				livehomescore	smallint,
				liveawayscore	smallint,
				betid			bigint,
				SportTypeId INT
	        )
	DECLARE @tblTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @today DATETIME
	SELECT @today = convert(varchar(10), getdate(),120)
		
	IF @Option = 0
	BEGIN
	    INSERT INTO @tblRecoverNG
		 SELECT z.transid,
	           z.custid,
			   b.recommend,
			   b.Username,
	           z.transdate,
	           z.odds,
	           z.stake,
	           z.winlost - b.actual_stake,
	           z.status,
	           b.CurrencyName,
	           b.bettype,
			   b.matchid,
			   b.oddstype,
			   z.betteam,
			   z.hdp1,
			   z.hdp2,
			   m.matchcode,
			   m.leagueid,
			   z.liveindicator,
			   z.livehomescore,
			   z.liveawayscore,
			   b.betid,
			   m.sporttype AS SportTypeId
	    FROM   zzzbettrans z WITH(NOLOCK)
	    INNER JOIN bettrans b WITH(NOLOCK)
	          ON  b.transid = z.transid AND b.matchid = z.matchid AND b.custid = z.custid
		INNER JOIN match m with(NOLOCK) ON z.matchid = m.matchid
	    WHERE  z.transid BETWEEN @FromTransId AND @ToTransId
	           AND z.matchid = @MatchId			   
			   AND (z.bettype BETWEEN 81 AND 120 OR z.bettype BETWEEN 8101 AND 8120)
			   and z.winlostdate = @today
	END
	ELSE 
	IF @Option = 1
	BEGIN
		INSERT INTO @tblTransIds
		SELECT ss.val FROM dbo.strSplit(@TransIds, ',') ss
	   
	    INSERT INTO @tblRecoverNG
	    SELECT z.transid,
	           z.custid,
			   b.recommend,   
			   b.Username,
	           z.transdate,
	           z.odds,
	           z.stake,
	           z.winlost - b.actual_stake,
	           z.status,
	           b.CurrencyName,
	           b.bettype,
			   b.matchid,
			   b.oddstype,
			   z.betteam,
			   z.hdp1,
			   z.hdp2,
			   m.matchcode,
			   m.leagueid,
			   z.liveindicator,
			   z.livehomescore,
			   z.liveawayscore,
			   b.betid,
			   m.sporttype AS SportTypeId
	    FROM   zzzbettrans z WITH(NOLOCK)
	           INNER JOIN bettrans b WITH(NOLOCK) ON  b.transid = z.transid
			   INNER JOIN match m WITH(NOLOCK) ON m.matchid = z.matchid
	    WHERE  z.transid IN (SELECT s.transid FROM   @tblTransIds s)
			   AND (z.bettype BETWEEN 81 AND 120 OR z.bettype BETWEEN 8101 AND 8120)
			   and z.winlostdate = @today
	END

	SELECT ag.site AS GroupName,
			t.transid,
			t.custid,
			c.username,
			c.username2,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.STATUS,
			t.CurrencyName,
			t.bettype,
			t.matchid,
			t.OddsType,
			t.betteam,
			t.hdp1,
			t.hdp2,
			t.MatchCode,
			t.leagueid,
			t.IsLiveIndicator,
			t.livehomescore,
			t.liveawayscore,
			t.betid,
			BS_tmp.BallSequence,
			SportTypeId
	FROM @tblRecoverNG t
	INNER JOIN CustDB.dbo.Customer ag WITH(NOLOCK) ON t.recommend = ag.custid
	INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
	OUTER APPLY (SELECT BallSequence 
				FROM dbo.f_NG_GetBallSequence (t.bettype, t.betteam , t.betid , t.IsLiveIndicator, t.livehomescore, t.liveawayscore)
				WHERE t.bettype IN (85, 86, 87, 88, 89, 90, 91)
				) AS BS_tmp	
	ORDER BY ag.SITE, t.transid

	--- invalid trans info
	SET @InvalidTransIds = ''
	IF @Option = 0
		SELECT @InvalidTransIds = @InvalidTransIds + 
								  CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END +
								  CAST(t.transid AS VARCHAR(100))  
		FROM @tblTransIds t
	ELSE -- @Option = 1
		SELECT @InvalidTransIds = @InvalidTransIds + 
								  CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END +
								  CAST(t.transid AS VARCHAR(100)) 
		FROM @tblTransIds t
		where t.transid not in (SELECT r.transid FROM @tblRecoverNG r)

		
END
GO