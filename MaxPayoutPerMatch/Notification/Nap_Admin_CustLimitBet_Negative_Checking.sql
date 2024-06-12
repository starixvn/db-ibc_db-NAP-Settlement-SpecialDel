/*<info serverAlias="DBSIG-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_Negative_Checking]
	@ErrorMessage VARCHAR(MAX) OUTPUT
AS
/*	
	Created: 20240610@Helen
    Task: Support check data for Max Payout Per Match setting - New Rule - New Job - [Redmine: #206245]
    DB: DBSIG-bodb02
    Revisions:
		- 20240610@Helen: Support check data for Max Payout Per Match setting - New Rule - New Job

	Param's explanation:		
		
*/
BEGIN	
	--------------Rule to check negative amount for all eventtypeid (not for phone betting) --------------------
	DECLARE @CustIDs VARCHAR(MAX) = ''
	DECLARE @UUSCustIDs VARCHAR(MAX) = ''
	DECLARE @UUSEventtypeIDs VARCHAR(1000) = ''
	DECLARE @EventtypeIDs VARCHAR(1000) = ''

	DECLARE @CRLF CHAR(2)

	SET @CRLF = CHAR(13)+CHAR(10)

	CREATE TABLE #Result_Negative_tmp (custid INT,eventtypeid TINYINT)

	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_789 -------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '', @UUSEventtypeIDs = ''
		
		TRUNCATE TABLE #Result_Negative_tmp

		INSERT INTO #Result_Negative_tmp (custid,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid,l.eventtypeid
		FROM CustLimitBet_789 l WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 betfrom FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID 
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
			AND tmp.betfrom <> 'p'
	
		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			SELECT @EventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_789 table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + '. Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			SELECT @UUSEventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_789 table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + '. Eventtypeid(s): '+ @UUSEventtypeIDs + @CRLF
		END
	END
	
	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_MBC -------------------------

	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '', @UUSEventtypeIDs = ''
		
		TRUNCATE TABLE #Result_Negative_tmp
		INSERT INTO #Result_Negative_tmp (custid,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid,l.eventtypeid
		FROM CustLimitBet_MBC l WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 betfrom FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID 
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
			AND tmp.betfrom <> 'p'
	
		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			SELECT @EventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_MBC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + '. Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			SELECT @UUSEventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_MBC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + '. Eventtypeid(s): '+ @UUSEventtypeIDs + @CRLF
		END
	END

	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_LIC -------------------------
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '', @UUSEventtypeIDs = ''
		
		TRUNCATE TABLE #Result_Negative_tmp

		INSERT INTO #Result_Negative_tmp (custid,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid,l.eventtypeid
		FROM CustLimitBet_LIC l WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 betfrom FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID 
						 ) AS tmp
		WHERE l.AccumTurnover < 0 
			AND tmp.betfrom <> 'p'
	
		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			SELECT @EventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_LIC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + '. Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			SELECT @UUSEventtypeIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.eventtypeid), ',') 
			FROM(
				SELECT DISTINCT b.eventtypeid
				FROM #Result_Negative_tmp b 
					INNER JOIN CUSTDB.dbo.Customer c WITH ( NOLOCK) ON b.custid = c.custid 
				WHERE c.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + 'CustLimitBet_LIC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + '. Eventtypeid(s): '+ @UUSEventtypeIDs + @CRLF
		END
	END
END