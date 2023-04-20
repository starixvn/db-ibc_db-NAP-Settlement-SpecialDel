/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Intg_SummaryRefNo_Retrieve_Void14_tmp] 
	@custId [int],
	@betTypeId [int],
	@winloseDate [smalldatetime],
	@sportTypeId [tinyint],
	@actualRate [float],
	@virtualRate [float],
	@recommend [int],
	@mrecommend [int],
	@srecommend [int],
	@betFrom [nvarchar](4),
	@currency [tinyint],
	@currencyName [varchar](50),
	@ip [varchar](15),
	@transdesc [nvarchar](1000) = null,
	@userName [varchar](50),
	@3rdCommShareRate smallmoney = 1, -- bettrans.modds
	@3rdInsuranceShareRate smallmoney = 0, -- bettrans.hdp2
	@3rdCreditRebateRate smallmoney = 0, -- bettrans.hdp1
	@refNo [bigint] OUTPUT
AS
BEGIN
/*
Creator : Helen
Date : 20200107
Task : Settlement VendorRNG
DB: DBTXN/bodb02

Revisions:
	--20200107@Helen: Support to void ticket in bettransRnG14 for Roulette - clone from Dot_Intg_SummaryRefNo_Retrieve - [148359]
	- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
*/
	select @refNo = 0

	set @winloseDate = convert(varchar(10), @winloseDate, 120)

	select top 1 @refNo = transid
	from dbo.bettrans14 (nolock)
	where custid = @custId 	
	and bettype = @betTypeId 
	and winlostdate=@winloseDate 
	and matchid=@sportTypeId
	and statusid in (0,111, 112, 113)
	order by statusID desc

	if(@refNo=0)
	begin
		declare 
		   @dbTime as datetime,
		   @abnormal bit
		set @dbTime = CURRENT_TIMESTAMP
		set @abnormal = 0

		if(@custid<>0 AND @recommend=0 AND @mrecommend=0 AND @srecommend=0)
	    begin
		    set @abnormal=1
	    end

		insert into dbo.bettrans14(bettype, betcheck, custid, transdate, hdp1, hdp2, odds,
									stake, status, actualrate, virtualrate, 
									winlost, awinlost, mwinlost, swinlost,	
									playercomm, comm, acomm, scomm, 
									apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, 
									playerdiscount, discount, adiscount, sdiscount, 
									recommend, mrecommend, srecommend,
									livehomescore, liveawayscore, liveindicator, oddsid, Creator, refno,
									Comstatus, winlostdate, betfrom, Checktime, oddsspread, matchid,
									ruben, betid, statuswinlost, modds, betdaqid,tstamp,
									actual_stake, currency, CurrencyName, ip, transdesc,
									Username, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, recommdate, epositiontaking
		)
		
		values(@betTypeId, 0, @custId, @dbTime, @3rdCreditRebateRate, @3rdInsuranceShareRate, 0,
				0, 'running', @actualRate, @virtualRate,
				0, 0, 0, 0, 
				0, 0, 0, 0, 
				0, 0, 0, 0, 
				0, 0, 0, 0, 
				@recommend, @mrecommend, @srecommend,
				0, 0, 0, 0, @custId, 0,
				null, @winloseDate, @betFrom, @dbTime, null, @sportTypeId,
				0, null, null, @3rdCommShareRate, null, null,
				0, @currency, @currencyName, @ip, @transdesc,
				@userName, null, 0, null, 0, null, null, null, 0
		)
		SELECT @refNo =SCOPE_IDENTITY()
		 
		 insert  INTO dbo.IntgUserLog ( userid, doing, logdate, notified, abnormal)
		 select  @custId,   
			     left('recommend=' + convert(varchar(10), @recommend) 
				 + ', mrecommend=' + convert(varchar(10), @mrecommend)
				 + ', srecommend=' + convert(varchar(10), @srecommend)
				 + ', winloseDate=' + convert(varchar(10), @winloseDate, 120)
				 + ', betFrom=' + convert(nvarchar(4), @betFrom)			
				 + ', sportTypeId=' + convert(varchar(5), @sportTypeId)
				 + ', betTypeId=' + convert(varchar(5), @betTypeId)
				 + ', currency=' + convert(varchar(4), @currency)
				 + ', currencyName=' + convert(varchar(50), @currencyName)
				 + ', IP=' + convert(varchar(15), @ip)
				 + ', transdesc=' + convert(varchar(200), isnull(@transdesc,''))
				 + ', userName=' + convert(varchar(50), @userName)
				 + ', transId=' + convert(varchar(30), @refNo)
				 + ', SP=Dot_Intg_SummaryRefNo_Retrieve_Void14_tmp',512)
				 ,   
				 @dbTime,  
				 0,
				 @abnormal
       
		 
		  
	end
END



GO


