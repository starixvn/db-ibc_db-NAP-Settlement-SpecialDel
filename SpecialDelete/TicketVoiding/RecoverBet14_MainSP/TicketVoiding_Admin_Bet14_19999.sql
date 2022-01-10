/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_Bet14_19999](@AffectedList VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20211229@Max: [TVS] Changes of TVS related to split Transfer out of bettrans [Redmine: #165093]
		
	Param's Explanation:  
	
	DECLARE @AffectedList VARCHAR(MAX), @xml XML
	SET @AffectedList = '<root>
						   <r c="2" st="100" ast="100" w="2019-06-14" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						   <r c="3" st="100" ast="100" w="2019-06-14" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						   <r c="3" st="100" ast="100" w="2019-06-15" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						</root>'

	SET @xml= CAST(@AffectedList as XML)

	SELECT r.value('@c','INT') AS CustID
		, r.value ('@w','SMALLDATETIME') AS winlostdate
		, r.value ('@w_dif','MONEY') AS winlost_dif
		, r.value ('@aw_dif','MONEY') AS awinlost_dif
		, r.value ('@mw_dif','MONEY') AS mwinlost_dif
		, r.value ('@sw_dif','MONEY') AS swinlost_dif
		, r.value ('@pc_dif','MONEY') AS playercomm_dif
		, r.value ('@c_dif','MONEY') AS comm_dif
		, r.value ('@ac_dif','MONEY') AS acomm_dif
		, r.value ('@sc_dif','MONEY') AS scomm_dif
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	   
*/
BEGIN
	
	SET NOCOUNT ON

	CREATE TABLE #Result_19999 (custid INT
							, winlostdate SMALLDATETIME
							, stake MONEY
							, actual_stake MONEY
							, winlost_dif MONEY
							, awinlost_dif MONEY
							, mwinlost_dif MONEY
							, swinlost_dif MONEY
							, playercomm_dif MONEY
							, comm_dif MONEY
							, acomm_dif MONEY
							, scomm_dif MONEY
						)
	DECLARE @xml XML
	SET @xml= CAST(@AffectedList AS XML)

	INSERT INTO #Result_19999 (custid,winlostdate
								, stake 
								, actual_stake 
								, winlost_dif, awinlost_dif, mwinlost_dif, swinlost_dif
								, playercomm_dif, comm_dif, acomm_dif, scomm_dif )
	SELECT r.value('@c','INT') AS CustID
		, r.value ('@w','SMALLDATETIME') AS winlostdate
		, r.value ('@st','MONEY') AS stake
		, r.value ('@ast','MONEY') AS actual_stake
		, r.value ('@w_dif','MONEY') AS winlost_dif
		, r.value ('@aw_dif','MONEY') AS awinlost_dif
		, r.value ('@mw_dif','MONEY') AS mwinlost_dif
		, r.value ('@sw_dif','MONEY') AS swinlost_dif
		, r.value ('@pc_dif','MONEY') AS playercomm_dif
		, r.value ('@c_dif','MONEY') AS comm_dif
		, r.value ('@ac_dif','MONEY') AS acomm_dif
		, r.value ('@sc_dif','MONEY') AS scomm_dif
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	UPDATE b
		SET 
			stake = b.stake + r.stake
			, actual_stake = b.actual_stake + r.actual_stake
			, winlost = b.winlost + r.winlost_dif
			, awinlost = b.awinlost + r.awinlost_dif
			, mwinlost = b.mwinlost + r.mwinlost_dif
			, swinlost = b.swinlost + r.swinlost_dif
			, playercomm = b.playercomm + r.playercomm_dif
			, comm = b.comm + r.comm_dif
			, acomm = b.acomm + r.acomm_dif
			, scomm = b.scomm + r.scomm_dif 
	FROM #Result_19999 r
		INNER LOOP JOIN dbo.Transfer b WITH (ROWLOCK) ON b.custid = r.custid AND b.winlostdate = r.winlostdate 
	WHERE b.bettype = 19999  
	
	-- Insert if not exists
	INSERT INTO dbo.Transfer
			(statusID, bettype, creator, transdate,
			custid, currency, recommend, mrecommend, srecommend,
			winlostdate, stake, winlost, awinlost, mwinlost, swinlost,
			actual_stake, playercomm, comm, acomm, scomm, 
			actualrate, Username, CurrencyName, checktime
			,refno)
	SELECT
		142, 19999, 8, r.winlostdate, --99
		r.custid, c.currency, c.recommend, c.mrecommend, c.srecommend,
		r.winlostdate, r.stake, r.winlost_dif, awinlost_dif, mwinlost_dif, swinlost_dif,
		r.actual_stake, r.playercomm_dif, r.comm_dif, r.acomm_dif, r.scomm_dif,
		rate.actualrate, c.username, e.currency, GETDATE()
		,0 -- for recover Bet14
	FROM #Result_19999 r with (nolock)
		INNER JOIN CustDB.dbo.custinfo c WITH (NOLOCK) ON r.custid = c.custid AND c.roleid = 1
		INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON e.exchangeid = c.currency
		CROSS APPLY (SELECT TOP 1 b14.actualrate
					 FROM bettrans14 b14 WITH (NOLOCK)
					 WHERE b14.winlostdate = r.winlostdate AND b14.bettype < = 19000 AND b14.currency = c.currency
					 ) AS rate
					 
		LEFT JOIN dbo.Transfer b WITH (NOLOCK) ON b.custid = r.custid AND  b.winlostdate = r.winlostdate AND b.bettype = 19999
	WHERE b.transid IS NULL
			
	DROP TABLE #Result_19999
	
END
GO
