/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Refund] 
	@AdminId			INT
	,@MatchId			INT
	,@RefundBettypes	VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation for Parlay Refund
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlBettype	 	XML
	DECLARE @tempBettype TABLE (bettype SMALLINT)
	
	--CONVERT bettype
	SET @xmlBettype = CONVERT(XML, @RefundBettypes)
	
	INSERT INTO @tempBettype (bettype)
	SELECT T.C.value('./@t', 'SMALLINT') AS bettype
	FROM @xmlBettype.nodes('/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	RETURN
END
GO