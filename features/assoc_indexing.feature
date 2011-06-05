Feature: Access to objects with indexed associations
  ROD allows for accessing objects via associations with indices.

  Background:
    Given the library works in development mode

  Scenario: indexing of singular associations
      It should be possible to index singular associations. This is
      useful when there are two databases and the other references
      objects from the first, but the first cannot directly reference
      objects from the second. In such a case, the second DB can have
      indices for the associations to speed-up object look-up.
    Given the class space is cleared
    And a class Caveman inherits from Rod::Model
    And a class Caveman has a name field of type string
    And a class Caveman is connected to Database1
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database2
    And a class Caveman has one automobile with flat index
    When the Database1 is created
    And the Database2 is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobile is the first Automobile created
    And I store him in the database
    And I reopen Database1 for reading
    And I reopen Database2 for reading
    Then there should be 1 Caveman
    And there should be 1 Automobile
    And there should be 1 Caveman with the first Automobile as automobile

  Scenario: indexing of plural associations
    Given the class space is cleared
    And a class Caveman inherits from Rod::Model
    And a class Caveman has a name field of type string
    And a class Caveman is connected to Database1
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database2
    And a class Caveman has many automobiles with flat index
    When the Database1 is created
    And the Database2 is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create another Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And I store him in the database
    And I reopen Database1 for reading
    And I reopen Database2 for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And there should be 1 Caveman with the first Automobile as automobiles
    And there should be 1 Caveman with the second Automobile as automobiles

