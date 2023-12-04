pragma solidity ^0.8.13;


contract TicketingSystem {

    struct Artist{
        bytes32 name;
        uint256 categorie;
        address owner;
        uint256 totalTicketSold;
    }

    struct Venue{
        bytes32 name;
        uint capacity;
        uint256 venueCommission;
        address payable owner;
    }

    struct Concert{
        uint256 artistId;
        uint256 venueId;
        uint256 concertDate;
        uint256 ticketPrice;
        bool validatedByArtist;
        bool validatedByVenue;
        uint256 totalTicketSold;
        uint256 totalMoneyCollected;
    }

    struct Ticket{
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }

    uint256 public artistCount = 0;
    uint256 public venueCount = 0;
    uint256 public concertCount = 0;
    uint256 public ticketCount = 0;

    //MAPPINGS & ARRAYS
    mapping(uint256 => Artist) public artistsRegister;
    mapping(bytes32 => uint256) private artistsId;

    mapping(uint256 => Venue) public venuesRegister;
    mapping(bytes32 => uint256) private venuesId;
    
    mapping(uint256 => Concert) public concertsRegister;
    // mapping(bytes32 => uint256) private concertsId;

    mapping(uint256 => Ticket) public ticketsRegister;
    mapping(bytes32 => uint256) private ticketsId;

    function createArtist(bytes32 _name, uint256 _artistCategory) public {
        require(bytes32(_name).length > 0, "Artist name cannot be empty");
        artistCount++;
        artistsRegister[artistCount] = Artist(_name, _artistCategory,msg.sender, 0);
        artistsId[_name] = artistCount;
    }

    function modifyArtist(uint256 _artistId, bytes32 _name, uint256 _artistCategory, address payable _newOwner) public{
        require(msg.sender == artistsRegister[_artistId].owner, "not the owner");
        artistsRegister[_artistId].name = _name;
        artistsRegister[_artistId].categorie = _artistCategory;
        artistsRegister[_artistId].owner = _newOwner;
    }

    //Venue
    function createVenue(bytes32 venueName, uint256 capacity, uint256 venueCommission) public{
        require(bytes32(venueName).length > 0, "Venue name cannot be empty");
        venueCount++;
        venuesRegister[venueCount] = Venue(venueName, capacity, venueCommission, payable(msg.sender));
        venuesId[venueName] = venueCount;
    }

    function modifyVenue(uint256 venueId, bytes32 venueName, uint256 capacity, uint256 venueCommission, address payable newOwner) public{
        require(msg.sender == venuesRegister[venueId].owner, "not the venue owner");
        venuesRegister[venueId].name = venueName;
        venuesRegister[venueId].capacity = capacity;
        venuesRegister[venueId].venueCommission = venueCommission;
        venuesRegister[venueId].owner = newOwner;
    }


    //Concert
    function createConcert(uint256 artistId, uint256 venueId, uint256 concertDate, uint256 ticketPrice) public{
        
        concertCount++;
        concertsRegister[concertCount] = Concert(artistId, venueId, concertDate, ticketPrice, false, false, 0, 0);
        if (msg.sender == artistsRegister[artistId].owner){
            concertsRegister[concertCount].validatedByArtist = true;
        }
        // concertsId[concertsRegister[concertCount].artistId] = concertCount;
    }

    function validateConcert(uint256 concertId) public{
        if (msg.sender == artistsRegister[concertsRegister[concertId].artistId].owner){
            concertsRegister[concertId].validatedByArtist = true;
        }
        if (msg.sender == venuesRegister[concertsRegister[concertId].venueId].owner){
            concertsRegister[concertId].validatedByVenue = true;
        }
    }

    function emitTicket(uint _concertId, address payable _ticketOwner) public{
        require(msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner, "not the owner");
        ticketCount++;
        ticketsRegister[ticketCount] = Ticket(_concertId, _ticketOwner, true, false, 0);
        concertsRegister[_concertId].totalTicketSold += 1;
    }

    function useTicket(uint _ticketId) public{
        require(msg.sender == ticketsRegister[_ticketId].owner, "sender should be the owner");
        require(concertsRegister[ticketsRegister[_ticketId].concertId].validatedByVenue, "should be validated by the venue");
        require(concertsRegister[ticketsRegister[_ticketId].concertId].concertDate <=block.timestamp +60*60*24 , "should be used the d-day");
        ticketsRegister[_ticketId].isAvailable = false;
        ticketsRegister[_ticketId].owner = payable(address(0));
    }

    function buyTicket(uint _concertId) public payable {
        ticketCount++;
        ticketsRegister[ticketCount] = Ticket(_concertId, payable(msg.sender), true, false, msg.value);
        concertsRegister[_concertId].totalTicketSold += 1;
        concertsRegister[_concertId].totalMoneyCollected += msg.value;
    }

    function transferTicket(uint _ticketId, address payable _newOwner) public{
        require(msg.sender == ticketsRegister[_ticketId].owner, "not the ticket owner");
        ticketsRegister[_ticketId].owner = _newOwner;
    }

    function cashOutConcert(uint _concertId, address payable _cashOutAddress) public {
        // Ensure that the current timestamp is after the concert date
        require(block.timestamp >= concertsRegister[_concertId].concertDate, "should be after the concert");

        // Ensure that the caller is the artist
        address artistOwner = artistsRegister[concertsRegister[_concertId].artistId].owner;
        require(msg.sender == artistOwner, "should be the artist");

        // Retrieve information about the concert
        Concert storage concert = concertsRegister[_concertId];

        // Calculate venue and artist commissions
        uint256 totalTicketSale = concert.totalTicketSold * 2;
        uint256 venueShare = (totalTicketSale * venuesRegister[concert.venueId].venueCommission) / 10000;
        uint256 artistCommission = totalTicketSale - venueShare;

        // Transfer funds to the venue owner
        payable(venuesRegister[concert.venueId].owner).transfer(venueShare);

        // Transfer funds to the artist
        payable(artistOwner).transfer(artistCommission);

        // Transfer remaining funds to the specified cash-out address
        payable(_cashOutAddress).transfer(address(this).balance);
    }
    

    function offerTicketForSale(uint _ticketId, uint _salePrice) public{
        require(msg.sender == ticketsRegister[_ticketId].owner, "should be the owner");
        require(_salePrice < ticketsRegister[_ticketId].amountPaid, "should be less than the amount paid");
        
        ticketsRegister[_ticketId].isAvailableForSale = true;
        ticketsRegister[_ticketId].amountPaid = _salePrice;

    }

    function buySecondHandTicket(uint256 _ticketId) public payable{
        require(msg.value >= ticketsRegister[_ticketId].amountPaid, "not enough funds");
        require(ticketsRegister[_ticketId].isAvailableForSale, "should be available");
        ticketsRegister[_ticketId].owner = payable(msg.sender);
        ticketsRegister[_ticketId].isAvailableForSale = false;
        ticketsRegister[_ticketId].amountPaid = msg.value;
    }
}