/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CustomerSelInfoByUsername]
	@UserName	VARCHAR(30)
AS
/*
Created: 20140911@Jamie
Task : Get CustID, RoleID, Currency by Username FOR all system 
DB: DBACC/BODB02
Original: Acc_CustomerSelInfoByUsername

Revisions:
	- 20201005@July: TVS - Enhance void by Bet ID to support void by customer [Redmine: #142010]
	
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #InputValidCustid_tmp  (custid INT, roleid TINYINT,currency INT)
	CREATE TABLE #InputValidCustid_2 (custid INT)

	INSERT INTO #InputValidCustid_tmp (custid, roleid,currency)	
	SELECT	 CustID
			,Roleid
			,currency
	FROM	dbo.custInfo WITH (NOLOCK)
	WHERE	UserName = @UserName

	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_tmp WHERE roleid = 1)
	BEGIN
		SELECT  CustID
			,Roleid
			,currency
		FROM #InputValidCustid_tmp
	END
	ELSE -- If SMA
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)		
		SELECT l.custid
		FROM #InputValidCustid_tmp l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_tmp WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)	
			SELECT ci.custid
			FROM #InputValidCustid_tmp l
				INNER JOIN custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			WHERE l.roleid = 3 AND ci.roleid = 2
		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_tmp WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT ci.custid
			FROM #InputValidCustid_tmp l
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			WHERE l.roleid = 4 AND ci.roleid = 2	
		END

		-- list of member to process
		SELECT ci.custid
			  ,ci.roleid
			  ,ci.currency
		FROM #InputValidCustid_2 lt
			INNER JOIN dbo.custInfo ci WITH (NOLOCK)
			ON lt.custid = ci.recommend
		WHERE ci.roleid = 1
	END

	DROP TABLE #InputValidCustid_tmp;
	DROP TABLE #InputValidCustid_2;
	
END
GO