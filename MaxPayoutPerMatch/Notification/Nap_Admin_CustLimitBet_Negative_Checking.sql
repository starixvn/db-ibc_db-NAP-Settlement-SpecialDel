/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_Negative_Checking]
	@StartTime DATETIME OUTPUT,
	@EndTime DATETIME OUTPUT,
	@ErrorMessage VARCHAR(MAX) OUTPUT
AS
BEGIN	
	--------------Rule to check negative amount for all eventtypeid (not for phone betting) --------------------
	DECLARE @CustIDs VARCHAR(MAX) = ''
	DECLARE @UUSCustIDs VARCHAR(MAX) = ''
	DECLARE @EventtypeIDs VARCHAR(1000) = ''

	CREATE TABLE #Result_Negative_tmp (custid INT,currency TINYINT, eventtypeid TINYINT )

	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_789 -------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp

		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_789 l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_789 table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_789 table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END
	
	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_MBC -------------------------

	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp
		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_MBC l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_MBC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_MBC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END

	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_LIC -------------------------
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp
		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_LIC l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_LIC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_LIC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END
END