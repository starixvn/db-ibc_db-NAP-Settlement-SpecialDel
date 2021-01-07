/*
Creator : Helen
Date : 20200107
Task : Settlement VendorRNG
DB: TransDB/bodb02

History:
	--20200107@Helen: Support to void ticket in bettransRnG14 for Roulette - [148359]
	
*/
EXEC Dot_Intg_Settlement_VendorRNG_Void14_tmp @transid_rng=102754618756 ,@custid=47485411,@productID=200,@gameID=1632,@odds=0,@stake=40,@payout=40,@statusID=102,@settleTime3rd='2021/1/1 10:55:11',@winlostdate='2021/1/1 00:00:00'
EXEC Dot_Intg_Settlement_VendorRNG_Void14_tmp @transid_rng=102755264965 ,@custid=47485411,@productID=200,@gameID=1632,@odds=0,@stake=20,@payout=20,@statusID=102,@settleTime3rd='2021/1/1 14:45:35',@winlostdate='2021/1/1 00:00:00'
EXEC Dot_Intg_Settlement_VendorRNG_Void14_tmp @transid_rng=102758269772 ,@custid=47502469,@productID=200,@gameID=1632,@odds=0,@stake=10,@payout=10,@statusID=102,@settleTime3rd='2021/1/2 13:12:58',@winlostdate='2021/1/2 00:00:00'
EXEC Dot_Intg_Settlement_VendorRNG_Void14_tmp @transid_rng=102758315358 ,@custid=47502469,@productID=200,@gameID=1632,@odds=0,@stake=400,@payout=400,@statusID=102,@settleTime3rd='2021/1/2 13:27:58',@winlostdate='2021/1/2 00:00:00'
EXEC Dot_Intg_Settlement_VendorRNG_Void14_tmp @transid_rng=102758324906 ,@custid=47502469,@productID=200,@gameID=1632,@odds=0,@stake=400,@payout=400,@statusID=102,@settleTime3rd='2021/1/2 13:30:59',@winlostdate='2021/1/2 00:00:00'