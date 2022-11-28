# Instructions 
## Auditing time
Starts on: `Sep 20, 2022 - 23:59 PDT` 

Ends on: `Sep 24, 2022 - 23:59 PDT` 

Submit your findings on the commit page. Please submit the findings by **commenting** on the issue in the corresponding file and line number for reviewers to easily refer to the code snippet. Please refer to the [sample comment](TBD) admin made for reference for the **required format** and "Issue Details" section for all the possible "Severity" and "Category" values.

Issue submission comment format
```
description: Reentrancy of sample contract test function (Sample)
recommendation: use the Checks-Effects-Interactions best practice and make all state changes before calling external contracts. Also, consider using function modifiers such as Reentrancy Guard to prevent re-entrancy from contract level.
locations: path/to/sample.sol#1-10,26
severity: Medium
category: Logical
```


## About the project:

**!!!!!! ALL the information is CONFIDENTIAL and under the protection of signed NDA**

Nothing Phone needs to launch NFT for its phone owner membership
- official website https://us.nothing.tech/

Client wants to have extra attention paid to the contract upgradeable feature 


## Auditing Scope
Audit scope includes all the contracts under `code` directory.

Code statistics:
```

Original repo commit: `7114d93c0bbd2f9d2d69da3fc4c3d2b9ab22673b` 

------------------------------------------------------------------------------------------
File                                                   blank        comment           code
------------------------------------------------------------------------------------------
./ERC1155NothingUpgradable.sol                            52              1            254
./utils/PaymentSplitterUppgradeable.sol                   24             52            112
./utils/Constants.sol                                      2              1              6
------------------------------------------------------------------------------------------
SUM:                                                      78             54            372
------------------------------------------------------------------------------------------
```

## Additional documents:
There are no additional documents provided by the client.

## Issue Details
Please assign the Severity and Category for each bug you find, Secure3 will review and reassign the bug across all the bugs found after the audit submission window cutoff.

- **Severity** value list: Informational / Medium / Low / Critical
- **Category** value list: Logical / Privilege Related / Language Specific / Code Style / Gas Optimization / Governance Manipulation / Reentrancy / Signature Forgery or Replay / DOS / Oracle Manipulation or Flash Loan Attacks / Integer Overflow and Underflow / Weak Sources of Randomness / Write to Arbitrary Storage Location / Race condition

