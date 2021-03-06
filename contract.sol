contract communityCurrency {
	
	//communityCurrency general variables
	address _treasury; //the address of the treasury of the DAO. The creator and minter of the currency
	address _community; //the address of the Community account. Where donations and taxes are paid. Account used to pay community works. 
	int _vatRate; //the depreciation at each transaction. The VAT to be paid to the DAO at the community account. % x 100
	uint _rewardRate; //reward Rate to the moneyLender of a successful credit, as a multiplier of the Reputation Cost of the credit. % x 100
	int _iniMemberCCUs; //initial Community Currency Units given to any new member. The monetary mass is automatically increased with any new member
	uint _iniMemberReputation; //initial Reputation given to any new member
	
	//communityCurrency parameters and key addresses of a given Community	
	function communityCurrency () {
		_treasury = msg.sender;  
		_community = 0x06400992be45bc64a52b5c55d3df84596d6cb4a1; 
		_vatRate = 3;
		_rewardRate = 20;
		_iniMemberCCUs = 25000;
		_iniMemberReputation = 100000;
	}
	
	//members wallet
	struct communityCurrencyWallet {
		int _communityCUnits; //balanceCCs is the actual balance of the currency CCs in the Wallet of the account. It can be negative!!!	
		uint _credit; //credit is the limit of balanceCCs the account is authorized to become negative	
		uint _deadline; //deadline is the time limit on which the credit should be already cancelled and becomes zero again. Its measured in number of _blocks
		address _moneyLender; //moneyLender is the address of the money lender. The credit line authorizer
		uint _unitsOfTrust; //unitsOfTrust is the cost in reputation (Units of Trust) of credit line the account has been authorized. The Trust endorsed to this account by the money lender. It is calculated in terms of credit volume = time x amountCCs
		bool _isMember; //if an address corresponds to an accepted member
		uint _reputation; //reputation is the volume of the credit in terms of balance of Units of Trust the money lender can authorize; that is, his available balance in Units of Trust he may endorse to others 
		uint _last; //time stamp of the last transaction
		uint _gdpActivity; //measures the average economic activity of the account. It measures the monetary mass moved by an account as m x v
	}
	
	mapping (address => communityCurrencyWallet) balancesOf;	
	
	event Transfer(uint _payment, int _myBalanceCCUs, address indexed _to);
	event Credit(uint _credit, uint _blocks, uint _myunitsOfTrust, uint _myReputationBalance, address indexed _borrower);

	//the community account can accept accounts as members. The Community should ensure the unique correspondence to a real person 
	//a community can opt to name itself member or not and therefore give credits or not
	function acceptMember (address _newMember) {
        if (msg.sender != _community) return;
        balancesOf[_newMember]._isMember = true;
        balancesOf[_newMember]._communityCUnits = _iniMemberCCUs;
        balancesOf[_newMember]._reputation = _iniMemberReputation;
        balancesOf[_newMember]._last = block.number;
    }
	//the community account can kick out members
	function kickOutMember (address _oldMember) {
        if (msg.sender != _community) return;
        balancesOf[_oldMember]._isMember = false;
        balancesOf[_oldMember]._reputation = 0;
        balancesOf[_oldMember]._credit = 0;
        balancesOf[_oldMember]._deadline = 0;
        balancesOf[_oldMember]._last = block.number;
    }

	//the treasury account can change the currency parameters;
	function newParameters (int _newVatRate, uint _newRewardRate, int _newIniCCUs, uint _newIniR) {
		_vatRate = _newVatRate;
		_rewardRate = _newRewardRate;
		_iniMemberCCUs = _newIniCCUs;
		_iniMemberReputation = _newIniR;
	}
	
	//the treasury account can issue as much communityCurrency it likes and send it to any Member; 
	//mint communityCurrency
	//warning: it increases the monetary mass. 
	function mintAssignCCUs (address _beneficiary, int _createCCUs) {
        if (msg.sender != _treasury) return;
		if (balancesOf[_beneficiary]._isMember != true) return;
		balancesOf[_beneficiary]._communityCUnits += _createCCUs;
	}

	//the community account can issue as much Reputation it likes and send it to any Member; 
	//mint Reputation
	function mintAssignReputation (address _beneficiary, uint _createReputation) {
        if (msg.sender != _community) return;
		if (balancesOf[_beneficiary]._isMember != true) return;
        balancesOf[_beneficiary]._reputation += _createReputation;
    }
	
	//function make a payment
	//anybody can make a payment if he has sufficient CCUs and or credit
	function transfer(address _payee, uint _payment) {
	//update the credit status
		if (balancesOf[msg.sender]._credit > 0) {
		//check if deadline is over
			if (block.number > balancesOf[msg.sender]._deadline) {
			//if time is over reset credit to zero, deadline to zero
				balancesOf[msg.sender]._deadline = 0;
				balancesOf[msg.sender]._credit = 0;
				//if balance is negative the credit was not returned, the money lender balanceReputation is not restored and is penalized with a 20%
				//as regards the borrower will not be able to make any new transfer until future incomes cover the debts
				if (balancesOf[msg.sender]._communityCUnits < 0) {
					balancesOf[balancesOf[msg.sender]._moneyLender]._reputation -= balancesOf[msg.sender]._unitsOfTrust * _rewardRate/100;
				}
					//if balance is not negative the credit was returned, the money lender balanceReputation is restored and is rewardRateed with a 20%
				else {
					balancesOf[balancesOf[msg.sender]._moneyLender]._reputation += balancesOf[msg.sender]._unitsOfTrust * (100 + _rewardRate)/100;
				}
				//reset money lender information
				balancesOf[msg.sender]._moneyLender = msg.sender; 
				balancesOf[msg.sender]._unitsOfTrust = 0;
		//if time is not over proceed with the payment
			}
	//if there was no credit proceed
		}
	//pay with the reviewed CCUs balance and credit
		int _creditLine = int(balancesOf[msg.sender]._credit);
		int _available = balancesOf[msg.sender]._communityCUnits + _creditLine; //is the spending limit of an account, given the account balance in _communityCUnits and the _credit
		int _amountCCUs = int(_payment); 
		if (_available > _amountCCUs) {
			balancesOf[msg.sender]._communityCUnits -= _amountCCUs;
			balancesOf[_payee]._communityCUnits += _amountCCUs;
			//apply vatRate and pay tax
			balancesOf[_payee]._communityCUnits -= _amountCCUs * _vatRate/100;
			balancesOf[_community]._communityCUnits += _amountCCUs * _vatRate/100;
			Transfer(_payment, balancesOf[msg.sender]._communityCUnits, _payee);
	//update the Activity indicator
			balancesOf[msg.sender]._gdpActivity = (balancesOf[msg.sender]._gdpActivity * balancesOf[msg.sender]._last + _payment)/block.number;
			balancesOf[msg.sender]._last = block.number;
		}
	}
	

	//function authorize a credit
	//only members can authorize or get a credit
	function credit(address _borrower, uint _credit, uint _blocks)  {
		if (balancesOf[msg.sender]._isMember != true) return;
		if (balancesOf[_borrower]._isMember != true) return;
			uint _unitsOfTrust = _credit * _blocks;
			if (balancesOf[msg.sender]._reputation > _unitsOfTrust) {
				balancesOf[msg.sender]._reputation -= _unitsOfTrust;
				balancesOf[_borrower]._credit += _credit;
				balancesOf[_borrower]._moneyLender = msg.sender;
				balancesOf[_borrower]._deadline = block.number + _blocks; //the _deadline is established as a number of _blocks ahead
				balancesOf[_borrower]._unitsOfTrust = _unitsOfTrust;
				Credit(_credit, _blocks, balancesOf[_borrower]._unitsOfTrust, balancesOf[msg.sender]._reputation, _borrower);
				}
	}

  	//monitor Wallet
    	function monitorWallet(address _monitored) constant returns (int _getCCUs, uint _getCredit, uint _getDeadline, address _getMoneyLender, uint _getUnitsOfTrust, bool _getIsMember, uint _getReputation, uint _getLast, uint _getGdpActivity  ) {
		if ((_monitored == msg.sender) || (msg.sender == _community) || (msg.sender == balancesOf[_monitored]._moneyLender)) {
    	_getCCUs = balancesOf[_monitored]._communityCUnits;	
		_getCredit = balancesOf[_monitored]._credit;
		_getDeadline = balancesOf[_monitored]._deadline;
		_getMoneyLender = balancesOf[_monitored]._moneyLender;
		_getUnitsOfTrust = balancesOf[_monitored]._unitsOfTrust;
		_getIsMember = balancesOf[_monitored]._isMember;
		_getReputation = balancesOf[_monitored]._reputation;
		_getLast = balancesOf[_monitored]._last;
		_getGdpActivity = balancesOf[_monitored]._gdpActivity;
		}
    	}
    
 	//authorize monitoring
	   function accessMyWallet (address _authorized) {
	   //during a credit, only the money lender and the community have access
	   //normally, the authorization to monitor own accounts is given to a candidate money lender
	   if (balancesOf[msg.sender]._credit != 0) return;
	   balancesOf[msg.sender]._moneyLender = _authorized;
   	}
}
